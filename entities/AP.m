classdef AP < handle
% AP: Access Point 클래스
%
% IEEE 802.11ax 네트워크의 AP를 모델링

    properties
        num_stas        % 연결된 STA 수
        bsr_table       % BSR 테이블 (STA별 버퍼 상태)
        thold_expiry    % T_hold 만료 시간 테이블 (STA별)
        
        %% 통계
        tf_count        % 발송한 TF 수
    end
    
    methods
        %% ═══════════════════════════════════════════════════
        %  생성자
        %  ═══════════════════════════════════════════════════
        
        function obj = AP(cfg)
            obj.num_stas = cfg.num_stas;
            
            % BSR 테이블 초기화 (모든 STA 버퍼 크기 = 0)
            obj.bsr_table = zeros(cfg.num_stas, 1);
            
            % T_hold 만료 테이블 초기화 (NaN = 비활성)
            obj.thold_expiry = nan(cfg.num_stas, 1);
            
            obj.tf_count = 0;
        end
        
        %% ═══════════════════════════════════════════════════
        %  BSR 업데이트
        %  ═══════════════════════════════════════════════════
        
        function update_bsr(obj, sta_idx, buffer_size)
            obj.bsr_table(sta_idx) = buffer_size;
        end
        
        %% ═══════════════════════════════════════════════════
        %  T_hold 시작
        %  ═══════════════════════════════════════════════════
        
        function start_thold(obj, sta_idx, expiry_slot)
            obj.thold_expiry(sta_idx) = expiry_slot;
        end
        
        %% ═══════════════════════════════════════════════════
        %  T_hold 종료
        %  ═══════════════════════════════════════════════════
        
        function end_thold(obj, sta_idx)
            obj.thold_expiry(sta_idx) = NaN;
        end
        
        %% ═══════════════════════════════════════════════════
        %  SA 스케줄링 대상 STA 목록 반환
        %  ═══════════════════════════════════════════════════
        
        function stas = get_sa_candidates(obj)
            % BSR > 0이거나 T_hold 활성인 STA
            stas = find(obj.bsr_table > 0 | ~isnan(obj.thold_expiry));
        end
    end
end
