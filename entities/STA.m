classdef STA < handle
% STA: Station 클래스
%
% IEEE 802.11ax 네트워크의 단말(Station)을 모델링

    properties
        id              % STA 고유 ID
        
        %% 모드 및 상태
        mode            % 0: RA (UORA), 1: SA (Scheduled Access)
        associated      % 연결 상태
        
        %% UORA 파라미터
        ocw             % 현재 OCW 값
        obo             % OBO (OFDMA Backoff) 카운터
        selected_ru     % 선택한 RU 인덱스
        assigned_ru     % 할당받은 RU 인덱스 (SA용)
        attempting      % 현재 전송 시도 중
        
        %% 큐 상태
        queue_size      % 현재 큐 크기 (bytes)
        queue_packets   % 큐에 있는 패킷 수
        
        %% 패킷 관리
        packets         % 패킷 배열 (구조체)
        num_packets     % 총 생성 패킷 수
        next_packet_idx % 다음 처리할 패킷 인덱스
        completed_packets % 완료된 패킷 수
        
        %% T_hold 상태
        thold_active    % T_hold 타이머 활성화
        thold_expiry    % T_hold 만료 슬롯
        thold_phantom_count  % 현재 activation의 Phantom 횟수
        thold_waiting_final  % M2: 만료 후 최종 할당 대기 중
        
        %% 통계
        tx_success      % 성공 전송 수
        tx_collision    % 충돌 수
        tx_bytes        % 전송 바이트
    end
    
    methods
        %% ═══════════════════════════════════════════════════
        %  생성자
        %  ═══════════════════════════════════════════════════
        
        function obj = STA(id, cfg)
            obj.id = id;
            
            % 모드 초기화 (RA 모드로 시작)
            obj.mode = 0;
            obj.associated = true;
            
            % UORA 파라미터 초기화
            obj.ocw = cfg.ocw_min;
            % OBO: 0 ~ OCW-1 범위 (기존 코드: floor(CW * rand()))
            obj.obo = floor(obj.ocw * rand());
            obj.selected_ru = 0;
            obj.assigned_ru = 0;
            obj.attempting = false;
            
            % 큐 초기화
            obj.queue_size = 0;
            obj.queue_packets = 0;
            
            % 패킷 관리 초기화
            obj.packets = [];
            obj.num_packets = 0;
            obj.next_packet_idx = 1;
            obj.completed_packets = 0;
            
            % T_hold 초기화
            obj.thold_active = false;
            obj.thold_expiry = 0;
            obj.thold_phantom_count = 0;
            obj.thold_waiting_final = false;
            
            % 통계 초기화
            obj.tx_success = 0;
            obj.tx_collision = 0;
            obj.tx_bytes = 0;
        end
        
        %% ═══════════════════════════════════════════════════
        %  상태 리셋
        %  ═══════════════════════════════════════════════════
        
        function reset(obj)
            obj.mode = 0;
            obj.ocw = 7;  % OCW_min
            obj.obo = floor(obj.ocw * rand());
            obj.selected_ru = 0;
            obj.assigned_ru = 0;
            obj.attempting = false;
            obj.thold_active = false;
            obj.thold_expiry = 0;
            obj.thold_phantom_count = 0;
            obj.thold_waiting_final = false;
        end
        
        %% ═══════════════════════════════════════════════════
        %  정보 출력
        %  ═══════════════════════════════════════════════════
        
        function disp_info(obj)
            mode_str = {'RA', 'SA'};
            fprintf('STA %d: Mode=%s, OCW=%d, OBO=%d, Queue=%d bytes (%d pkts)\n', ...
                obj.id, mode_str{obj.mode+1}, obj.ocw, obj.obo, ...
                obj.queue_size, obj.queue_packets);
        end
    end
    
    methods (Static)
        %% ═══════════════════════════════════════════════════
        %  패킷 구조체 템플릿
        %  ═══════════════════════════════════════════════════
        
        function pkt = create_packet(idx, size, arrival_time)
            pkt.idx = idx;
            pkt.size = size;
            pkt.arrival_time = arrival_time;
            pkt.enqueue_slot = 0;
            pkt.completion_slot = 0;
            pkt.completed = false;
            pkt.delay_slots = 0;
            
            %% ═══════════════════════════════════════════════════
            %  지연 분해용 타이밍 필드 (Delay Decomposition)
            %  ═══════════════════════════════════════════════════
            
            % 첫 TF 슬롯 (Initial Wait 계산용)
            pkt.first_tf_slot = 0;
            
            % UORA 경쟁 구간 (RA 모드에서만 해당)
            pkt.uora_start_slot = 0;    % UORA 경쟁 시작 슬롯
            pkt.uora_end_slot = 0;      % UORA 성공 슬롯
            
            % SA 스케줄링 구간
            pkt.sa_start_slot = 0;      % SA 모드 진입 슬롯
            
            % 전송 정보
            pkt.tx_type = '';           % 'ra' | 'sa'
            
            %% ═══════════════════════════════════════════════════
            %  패킷 분류 (UORA 스킵 여부)
            %  ═══════════════════════════════════════════════════
            
            % UORA 스킵 여부 (T_hold hit + SA queue 모두 포함)
            pkt.uora_skipped = false;
            
            % 스킵 이유
            %   'thold_hit': T_hold 중에 도착 → UORA 스킵
            %   'sa_queue':  이미 SA 모드 (큐에 다른 패킷) → UORA 스킵
            %   '':          RA 모드 → UORA 경쟁 필요
            pkt.skip_reason = '';
            
            % 하위 호환성 (기존 thold_hit 필드 유지)
            pkt.thold_hit = false;      % T_hold Hit으로 UORA 회피 여부
            
            %% ═══════════════════════════════════════════════════
            %  분해된 지연 값 (슬롯 단위, 완료 시 계산)
            %  ═══════════════════════════════════════════════════
            
            % Initial Wait: 패킷 도착 → 첫 TF
            pkt.initial_wait_slots = 0;
            
            % UORA Contention: 첫 TF → UORA 성공 (RA 모드 경유 시)
            pkt.uora_contention_slots = 0;
            
            % SA Scheduling Wait: SA 진입 → 전송 완료
            pkt.sa_wait_slots = 0;
        end
    end
end