classdef UORAProcessor < handle
% UORAPROCESSOR: UORA (Uplink OFDMA Random Access) 프로세서
%
% IEEE 802.11ax UORA 메커니즘 처리

    properties
        num_ra_ru       % RA-RU 수
        ocw_min         % OCW 최소값
        ocw_max         % OCW 최대값
    end
    
    methods
        %% ═══════════════════════════════════════════════════
        %  생성자
        %  ═══════════════════════════════════════════════════
        
        function obj = UORAProcessor(cfg)
            obj.num_ra_ru = cfg.num_ru_ra;
            obj.ocw_min = cfg.ocw_min;
            obj.ocw_max = cfg.ocw_max;
        end
        
        %% ═══════════════════════════════════════════════════
        %  UORA 처리 (OBO 감소 및 전송 결정)
        %  ═══════════════════════════════════════════════════
        
        function attempts = process(obj, stas)
            attempts = struct('sta_idx', {}, 'ru_idx', {});
            
            for i = 1:length(stas)
                sta = stas(i);
                
                % RA 모드이고 큐에 데이터가 있으면 UORA 참여
                if sta.mode == 0 && sta.queue_size > 0
                    % OBO 카운터 감소
                    sta.obo = sta.obo - obj.num_ra_ru;
                    
                    % OBO <= 0이면 RA-RU 접근 시도
                    if sta.obo <= 0
                        % 랜덤 RU 선택 (1 ~ num_ra_ru)
                        selected_ru = randi(obj.num_ra_ru);
                        sta.selected_ru = selected_ru;
                        sta.attempting = true;
                        
                        attempts(end+1).sta_idx = i;
                        attempts(end).ru_idx = selected_ru;
                    else
                        sta.attempting = false;
                        sta.selected_ru = 0;
                    end
                else
                    sta.attempting = false;
                    sta.selected_ru = 0;
                end
                
                stas(i) = sta;
            end
        end
        
        %% ═══════════════════════════════════════════════════
        %  전송 성공 시 처리
        %  ═══════════════════════════════════════════════════
        
        function handle_success(obj, sta)
            % OCW 리셋
            sta.ocw = obj.ocw_min;
            % OBO: 0 ~ OCW-1 범위 (기존 코드: floor(CW * rand()))
            sta.obo = floor(sta.ocw * rand());
            sta.attempting = false;
            sta.selected_ru = 0;
        end
        
        %% ═══════════════════════════════════════════════════
        %  전송 충돌 시 처리 (BEB)
        %  ═══════════════════════════════════════════════════
        
        function handle_collision(obj, sta)
            % Binary Exponential Backoff: CW = (CW+1)*2 - 1
            sta.ocw = min((sta.ocw + 1) * 2 - 1, obj.ocw_max);
            % OBO: 0 ~ OCW-1 범위 (기존 코드: floor(CW * rand()))
            sta.obo = floor(sta.ocw * rand());
            sta.attempting = false;
            sta.selected_ru = 0;
        end
    end
end