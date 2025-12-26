classdef BSRManager < handle
% BSRMANAGER: Buffer Status Report 관리자
%
% Explicit BSR (UORA 전송 후)와 Implicit BSR (SA 전송 후) 처리

    properties
        %% 통계
        explicit_count  % Explicit BSR 횟수
        implicit_count  % Implicit BSR 횟수
    end
    
    methods
        %% ═══════════════════════════════════════════════════
        %  생성자
        %  ═══════════════════════════════════════════════════
        
        function obj = BSRManager(~)
            obj.explicit_count = 0;
            obj.implicit_count = 0;
        end
        
        %% ═══════════════════════════════════════════════════
        %  Explicit BSR 처리 (UORA 전송 성공 시)
        %  ═══════════════════════════════════════════════════
        
        function process_explicit(obj, sta, ap, sta_idx)
            % UORA 전송 성공 → BSR 전송 (현재 버퍼 상태)
            buffer_status = sta.queue_size;
            ap.update_bsr(sta_idx, buffer_status);
            
            obj.explicit_count = obj.explicit_count + 1;
        end
        
        %% ═══════════════════════════════════════════════════
        %  Implicit BSR 처리 (SA 전송 시)
        %  ═══════════════════════════════════════════════════
        
        function process_implicit(obj, sta, ap, sta_idx)
            % SA 전송 → 현재 버퍼 상태가 암묵적으로 AP에 전달
            buffer_status = sta.queue_size;
            ap.update_bsr(sta_idx, buffer_status);
            
            obj.implicit_count = obj.implicit_count + 1;
        end
        
        %% ═══════════════════════════════════════════════════
        %  통계 반환
        %  ═══════════════════════════════════════════════════
        
        function stats = get_stats(obj)
            stats.explicit_count = obj.explicit_count;
            stats.implicit_count = obj.implicit_count;
            
            total = obj.explicit_count + obj.implicit_count;
            if total > 0
                stats.explicit_ratio = obj.explicit_count / total;
            else
                stats.explicit_ratio = 0;
            end
        end
    end
end
