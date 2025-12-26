classdef CollisionDetector < handle
% COLLISIONDETECTOR: RU 충돌 검출기
%
% 각 RU의 점유 상태를 확인하여 성공/충돌/유휴 판정

    properties
        num_ra_ru       % RA-RU 수
        num_sa_ru       % SA-RU 수
    end
    
    methods
        %% ═══════════════════════════════════════════════════
        %  생성자
        %  ═══════════════════════════════════════════════════
        
        function obj = CollisionDetector(cfg)
            obj.num_ra_ru = cfg.num_ru_ra;
            obj.num_sa_ru = cfg.num_ru_sa;
        end
        
        %% ═══════════════════════════════════════════════════
        %  충돌 검출
        %  ═══════════════════════════════════════════════════
        
        function [success, collided, idle] = detect(obj, stas, rus, ra_attempts, sa_assignments)
            % 결과 초기화
            success = struct('sta_idx', {}, 'tx_type', {}, 'ru_idx', {});
            collided = [];
            idle = struct('ra', 0, 'sa', 0);
            
            % RU 리셋
            rus.reset();
            
            %% ═══════════════════════════════════════════════
            %  RA-RU 접근 등록
            %  ═══════════════════════════════════════════════
            
            for i = 1:length(ra_attempts)
                sta_idx = ra_attempts(i).sta_idx;
                ru_idx = ra_attempts(i).ru_idx;
                rus.register_access(ru_idx, sta_idx);
            end
            
            %% ═══════════════════════════════════════════════
            %  SA-RU 접근 등록
            %  ═══════════════════════════════════════════════
            
            for i = 1:length(sa_assignments)
                sta_idx = sa_assignments(i).sta_idx;
                ru_idx = sa_assignments(i).ru_idx;
                rus.register_access(ru_idx, sta_idx);
            end
            
            %% ═══════════════════════════════════════════════
            %  상태 업데이트 및 결과 판정
            %  ═══════════════════════════════════════════════
            
            rus.update_status();
            
            % RA-RU 결과 처리
            for ru_idx = 1:obj.num_ra_ru
                occupants = rus.occupants{ru_idx};
                
                if isempty(occupants)
                    idle.ra = idle.ra + 1;
                elseif length(occupants) == 1
                    % 성공
                    success(end+1).sta_idx = occupants(1);
                    success(end).tx_type = 'ra';
                    success(end).ru_idx = ru_idx;
                else
                    % 충돌
                    collided = [collided, occupants];
                end
            end
            
            % SA-RU 결과 처리
            for ru_offset = 1:obj.num_sa_ru
                ru_idx = obj.num_ra_ru + ru_offset;
                occupants = rus.occupants{ru_idx};
                
                if isempty(occupants)
                    idle.sa = idle.sa + 1;
                elseif length(occupants) == 1
                    % SA는 스케줄되므로 충돌 없음 (정상)
                    success(end+1).sta_idx = occupants(1);
                    success(end).tx_type = 'sa';
                    success(end).ru_idx = ru_idx;
                else
                    % SA에서 충돌은 스케줄러 오류
                    warning('SA-RU에서 충돌 발생! RU=%d, STAs=%s', ...
                        ru_idx, mat2str(occupants));
                end
            end
            
            % 중복 제거 (같은 STA가 여러 RU에서 충돌한 경우)
            collided = unique(collided);
        end
    end
end
