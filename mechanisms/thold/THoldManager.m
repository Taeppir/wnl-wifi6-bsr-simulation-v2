classdef THoldManager < handle
% THOLDMANAGER: T_hold 메커니즘 관리자
%
% 버퍼가 비어도 SA 모드를 유지하여 UORA 경쟁을 회피하는 메커니즘

    properties
        enabled         % T_hold 활성화 여부
        thold_slots     % T_hold 값 (슬롯 단위)
        policy          % 정책: 'fixed' | 'adaptive'
        method          % Method: 'M0' | 'M1' | 'M2'
        
        %% 통계
        activations     % T_hold 발동 횟수
        hits            % T_hold 중 SA 할당 + 버퍼 있음 (성공)
        expirations     % T_hold 만료 횟수 (total)
        clean_exp       % Clean 만료: 만료 시 버퍼 empty → RA 전환
        exp_with_data   % 데이터 있는 만료: 만료 시 버퍼 있음
        phantoms        % Phantom 횟수: SA 할당 + 버퍼 empty (여러 번 가능)
        wasted_slots    % 낭비된 슬롯 (만료 시 전체 T_hold 기간)
    end
    
    methods
        %% ═══════════════════════════════════════════════════
        %  생성자
        %  ═══════════════════════════════════════════════════
        
        function obj = THoldManager(cfg)
            obj.enabled = cfg.thold_enabled;
            obj.thold_slots = cfg.thold_slots;
            obj.policy = cfg.thold_policy;
            obj.method = cfg.thold_method;  % 'M0', 'M1', 'M2'
            
            obj.activations = 0;
            obj.hits = 0;
            obj.expirations = 0;
            obj.clean_exp = 0;
            obj.exp_with_data = 0;
            obj.phantoms = 0;
            obj.wasted_slots = 0;
        end
        
        %% ═══════════════════════════════════════════════════
        %  T_hold 타이머 시작
        %  ═══════════════════════════════════════════════════
        
        function start_timer(obj, sta, ap, sta_idx, current_slot)
            if ~obj.enabled
                return;
            end
            
            expiry_slot = current_slot + obj.thold_slots;
            
            % STA 상태 업데이트
            sta.thold_active = true;
            sta.thold_expiry = expiry_slot;
            sta.thold_phantom_count = 0;  % 새 activation, phantom 카운트 리셋
            sta.mode = 1;  % SA 모드 유지
            
            % AP 상태 업데이트
            ap.start_thold(sta_idx, expiry_slot);
            
            obj.activations = obj.activations + 1;
        end
        
        %% ═══════════════════════════════════════════════════
        %  T_hold 만료 체크
        %  ═══════════════════════════════════════════════════
        
        function check_expiry(obj, stas, ap, current_slot)
            if ~obj.enabled
                return;
            end
            
            for i = 1:length(stas)
                sta = stas(i);
                
                if sta.thold_active && sta.thold_expiry <= current_slot
                    % T_hold 만료!
                    obj.expirations = obj.expirations + 1;
                    
                    if strcmp(obj.method, 'M2')
                        % M2: 만료 시 바로 전환하지 않고 waiting_final 상태로
                        sta.thold_active = false;
                        sta.thold_expiry = 0;
                        sta.thold_waiting_final = true;
                        % mode는 SA 유지, 다음 schedule_sa_ru에서 처리됨
                        
                    elseif sta.queue_size == 0
                        % M0/M1: Clean Expiration - 버퍼가 여전히 비어있음 → RA 모드로 전환
                        sta.mode = 0;
                        sta.thold_active = false;
                        sta.thold_expiry = 0;
                        
                        % AP T_hold 상태 해제
                        ap.end_thold(i);
                        
                        obj.clean_exp = obj.clean_exp + 1;
                        
                        % 낭비된 슬롯 기록 (전체 T_hold 기간 기다렸지만 패킷 안 옴)
                        obj.wasted_slots = obj.wasted_slots + obj.thold_slots;
                    else
                        % M0/M1: Expiration with Data - 버퍼에 데이터 있음
                        % T_hold 중 패킷 도착했지만 SA 할당 못 받은 경우
                        % → RA 모드로 전환하여 UORA 참여 가능하게 함!
                        sta.mode = 0;  % 버그 수정: RA 모드로 전환!
                        sta.thold_active = false;
                        sta.thold_expiry = 0;
                        
                        % AP T_hold 상태 해제
                        ap.end_thold(i);
                        
                        obj.exp_with_data = obj.exp_with_data + 1;
                    end
                    
                    stas(i) = sta;
                end
            end
        end
        
        %% ═══════════════════════════════════════════════════
        %  T_hold 중 새 패킷 도착 처리
        %  ═══════════════════════════════════════════════════
        
        function handle_new_packet(obj, sta, ap, current_slot)
            if ~obj.enabled || ~sta.thold_active
                return;
            end
            
            % T_hold 중에 패킷 도착!
            % thold_active는 유지 → 다음 TF에서 SA 할당 받기 위해
            % 실제 Hit 판정은 Phase 3.5에서 (SA 할당 + 버퍼 확인)
            
            % Note: thold_active = false는 여기서 하지 않음!
            % Phase 3.5에서 SA 할당 시점에 처리
            
            % hits 카운트도 Phase 3.5에서 (실제 전송 성공 시)
        end
        
        %% ═══════════════════════════════════════════════════
        %  통계 반환
        %  ═══════════════════════════════════════════════════
        
        function stats = get_stats(obj)
            stats.activations = obj.activations;
            stats.hits = obj.hits;
            stats.expirations = obj.expirations;
            stats.clean_exp = obj.clean_exp;
            stats.exp_with_data = obj.exp_with_data;
            stats.phantoms = obj.phantoms;
            stats.wasted_slots = obj.wasted_slots;
            
            if obj.activations > 0
                stats.hit_rate = obj.hits / obj.activations;
                stats.phantom_per_activation = obj.phantoms / obj.activations;
            else
                stats.hit_rate = 0;
                stats.phantom_per_activation = 0;
            end
            
            stats.uora_avoided = obj.hits;  % Hit된 경우 UORA 경쟁 회피
        end
    end
end