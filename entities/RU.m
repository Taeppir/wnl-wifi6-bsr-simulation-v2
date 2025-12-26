classdef RU < handle
% RU: Resource Unit 클래스
%
% IEEE 802.11ax OFDMA Resource Unit 모델링

    properties
        num_total       % 총 RU 수
        num_ra          % RA-RU 수 (AID=0)
        num_sa          % SA-RU 수 (스케줄)
        
        % 현재 슬롯 상태
        status          % 각 RU 상태 (0: idle, 1: success, 2: collision)
        occupants       % 각 RU를 점유 시도한 STA 목록
    end
    
    methods
        %% ═══════════════════════════════════════════════════
        %  생성자
        %  ═══════════════════════════════════════════════════
        
        function obj = RU(cfg)
            obj.num_total = cfg.num_ru_total;
            obj.num_ra = cfg.num_ru_ra;
            obj.num_sa = cfg.num_ru_sa;
            
            obj.reset();
        end
        
        %% ═══════════════════════════════════════════════════
        %  슬롯 시작 시 리셋
        %  ═══════════════════════════════════════════════════
        
        function reset(obj)
            obj.status = zeros(obj.num_total, 1);
            obj.occupants = cell(obj.num_total, 1);
        end
        
        %% ═══════════════════════════════════════════════════
        %  RU 접근 등록
        %  ═══════════════════════════════════════════════════
        
        function register_access(obj, ru_idx, sta_idx)
            if ru_idx > 0 && ru_idx <= obj.num_total
                obj.occupants{ru_idx}(end+1) = sta_idx;
            end
        end
        
        %% ═══════════════════════════════════════════════════
        %  상태 업데이트
        %  ═══════════════════════════════════════════════════
        
        function update_status(obj)
            for i = 1:obj.num_total
                n = length(obj.occupants{i});
                if n == 0
                    obj.status(i) = 0;  % Idle
                elseif n == 1
                    obj.status(i) = 1;  % Success
                else
                    obj.status(i) = 2;  % Collision
                end
            end
        end
        
        %% ═══════════════════════════════════════════════════
        %  통계 반환
        %  ═══════════════════════════════════════════════════
        
        function [idle, success, collision] = get_ra_stats(obj)
            ra_status = obj.status(1:obj.num_ra);
            idle = sum(ra_status == 0);
            success = sum(ra_status == 1);
            collision = sum(ra_status == 2);
        end
    end
end
