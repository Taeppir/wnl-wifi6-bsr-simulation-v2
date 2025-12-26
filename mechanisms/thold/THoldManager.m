classdef THoldManager < handle
% THOLDMANAGER: T_hold 메커니즘 관리자
%
% 버퍼가 비어도 SA 모드를 유지하여 UORA 경쟁을 회피하는 메커니즘

    properties
        enabled         % T_hold 활성화 여부
        thold_slots     % T_hold 값 (슬롯 단위)
        policy          % 정책: 'fixed' | 'adaptive'
        
        %% 통계
        activations     % T_hold 발동 횟수
        hits            % T_hold 중 패킷 도착 횟수 (적중)
        expirations     % T_hold 만료 횟수 (미적중)
    end
    
    methods
        %% ═══════════════════════════════════════════════════
        %  생성자
        %  ═══════════════════════════════════════════════════
        
        function obj = THoldManager(cfg)
            obj.enabled = cfg.thold_enabled;
            obj.thold_slots = cfg.thold_slots;
            obj.policy = cfg.thold_policy;
            
            obj.activations = 0;
            obj.hits = 0;
            obj.expirations = 0;
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
            sta.mode = 1;  % SA 모드 유지
            
            % AP 상태 업데이트
            ap.start_thold(sta_idx, expiry_slot);
            
            obj.activations = obj.activations + 1;
        end
        
        %% ═══════════════════════════════════════════════════
        %  T_hold 만료 체크 (구간 기반)
        %  ═══════════════════════════════════════════════════
        
        function check_expiry(obj, stas, ap, prev_slot, current_slot)
            % (prev_slot, current_slot] 구간에서 만료되는 T_hold 체크
            if ~obj.enabled
                return;
            end
            
            for i = 1:length(stas)
                sta = stas(i);
                
                % T_hold가 활성화되어 있고, 만료 시점이 구간 내에 있는지 확인
                % prev_slot < thold_expiry <= current_slot
                if sta.thold_active && ...
                   sta.thold_expiry > prev_slot && ...
                   sta.thold_expiry <= current_slot
                    
                    % T_hold 만료!
                    if sta.queue_size == 0
                        % 버퍼가 여전히 비어있음 → RA 모드로 전환
                        sta.mode = 0;
                        sta.thold_active = false;
                        sta.thold_expiry = 0;
                        
                        % AP BSR 초기화
                        ap.bsr_table(i) = 0;
                        ap.end_thold(i);
                        
                        obj.expirations = obj.expirations + 1;
                    else
                        % 버퍼에 데이터 있음 (이미 hit 처리됨)
                        sta.thold_active = false;
                        sta.thold_expiry = 0;
                    end
                    
                    stas(i) = sta;
                end
            end
        end
        
        %% ═══════════════════════════════════════════════════
        %  T_hold 중 새 패킷 도착 처리
        %  ═══════════════════════════════════════════════════
        
        function handle_new_packet(obj, sta, ap, arrival_slot, current_slot)
            % arrival_slot: 패킷의 실제 도착 슬롯
            % current_slot: 현재 TF 시점 (처리 시점)
            
            if ~obj.enabled || ~sta.thold_active
                return;
            end
            
            % 패킷 도착이 T_hold 만료 전인지 확인
            % arrival_slot < thold_expiry 이면 Hit!
            if arrival_slot < sta.thold_expiry
                % T_hold Hit! SA 모드 유지, 타이머 해제
                sta.thold_active = false;
                sta.thold_expiry = 0;
                % sta.mode는 이미 1 (SA)
                
                % AP 측 T_hold도 해제
                ap.end_thold(sta.id);
                
                obj.hits = obj.hits + 1;
            else
                % 패킷 도착이 T_hold 만료 후 → Miss
                % (이 경우는 check_expiry에서 이미 RA 모드로 전환됨)
                % 여기 도달하면 안 됨 (thold_active가 false일 것)
            end
        end
        
        %% ═══════════════════════════════════════════════════
        %  통계 반환
        %  ═══════════════════════════════════════════════════
        
        function stats = get_stats(obj)
            stats.activations = obj.activations;
            stats.hits = obj.hits;
            stats.expirations = obj.expirations;
            
            if obj.activations > 0
                stats.hit_rate = obj.hits / obj.activations;
            else
                stats.hit_rate = 0;
            end
            
            stats.uora_avoided = obj.hits;  % Hit된 경우 UORA 경쟁 회피
        end
    end
end