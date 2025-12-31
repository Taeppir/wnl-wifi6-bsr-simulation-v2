function cfg = validate_config(cfg)
% VALIDATE_CONFIG: 설정 검증 및 파생값 계산
%
% 입력: cfg - 설정 구조체
% 출력: cfg - 검증 및 파생값 계산된 설정 구조체

    %% ═══════════════════════════════════════════════════
    %  슬롯 변환
    %  ═══════════════════════════════════════════════════
    
    % 시뮬레이션 시간 → 슬롯
    cfg.total_slots = ceil(cfg.simulation_time / cfg.slot_duration);
    cfg.warmup_slots = ceil(cfg.warmup_time / cfg.slot_duration);
    
    % T_hold 슬롯 변환
    if cfg.thold_enabled && cfg.thold_value > 0
        cfg.thold_slots = ceil(cfg.thold_value / cfg.slot_duration);
    else
        cfg.thold_slots = 0;
    end
    
    %% ═══════════════════════════════════════════════════
    %  RU 구성 검증
    %  ═══════════════════════════════════════════════════
    
    % num_ru_sa 자동 계산 (필요시)
    if ~isfield(cfg, 'num_ru_sa') || cfg.num_ru_sa == 0
        cfg.num_ru_sa = cfg.num_ru_total - cfg.num_ru_ra;
    end
    
    % 검증
    assert(cfg.num_ru_ra + cfg.num_ru_sa <= cfg.num_ru_total, ...
        'RA-RU + SA-RU가 총 RU 수를 초과합니다.');
    
    %% ═══════════════════════════════════════════════════
    %  트래픽 파라미터 검증
    %  ═══════════════════════════════════════════════════
    
    % mu_off 자동 계산 (필요시)
    if strcmp(cfg.traffic_model, 'pareto_onoff')
        if ~isfield(cfg, 'mu_off') || cfg.mu_off == 0
            cfg.mu_off = cfg.mu_on * (1 - cfg.rho) / cfg.rho;
        end
    end
    
    %% ═══════════════════════════════════════════════════
    %  프레임 길이 재계산 (MPDU 크기 변경 시)
    %  ═══════════════════════════════════════════════════
    
    % 데이터 전송 슬롯 (MPDU 기준)
    data_tx_time = (cfg.mpdu_size * 8) / cfg.data_rate_per_ru;
    cfg.data_tx_slots = ceil(data_tx_time / cfg.slot_duration);
    
    % TF 주기 재계산
    cfg.frame_exchange_slots = cfg.len_phy_header_slots + cfg.len_tf_slots + ...
                               cfg.sifs_slots + ...
                               cfg.len_phy_header_slots + cfg.data_tx_slots + ...
                               cfg.sifs_slots + ...
                               cfg.len_phy_header_slots + cfg.len_mu_back_slots + ...
                               cfg.sifs_slots;
    
    %% ═══════════════════════════════════════════════════
    %  출력 (verbose 모드)
    %  ═══════════════════════════════════════════════════
    
    if isfield(cfg, 'verbose') && cfg.verbose >= 2
        fprintf('\n[설정 검증 완료]\n');
        fprintf('  시뮬레이션: %d slots (%.1f초)\n', cfg.total_slots, cfg.simulation_time);
        fprintf('  워밍업: %d slots (%.1f초)\n', cfg.warmup_slots, cfg.warmup_time);
        fprintf('  T_hold: %d slots (%.1fms)\n', cfg.thold_slots, cfg.thold_value * 1000);
        fprintf('  TF 주기: %d slots (%.3fms)\n', cfg.frame_exchange_slots, ...
            cfg.frame_exchange_slots * cfg.slot_duration * 1000);
    end
end