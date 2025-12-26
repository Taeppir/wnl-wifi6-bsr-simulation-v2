function [passed, failed] = test_config()
% TEST_CONFIG: config_default 테스트
%
% 테스트 항목:
%   1. 설정 로드
%   2. PHY 파라미터 값 확인
%   3. 파생값 계산 확인

    passed = 0;
    failed = 0;
    
    %% Test 1: 설정 로드
    fprintf('  [1] 설정 로드... ');
    try
        cfg = config_default();
        assert(~isempty(cfg), '설정이 비어있음');
        fprintf('✓\n');
        passed = passed + 1;
    catch ME
        fprintf('✗ (%s)\n', ME.message);
        failed = failed + 1;
    end
    
    %% Test 2: PHY 파라미터 (Table 1 기준)
    fprintf('  [2] PHY 파라미터 확인... ');
    try
        assert(cfg.slot_duration == 9e-6, 'slot_duration != 9us');
        assert(cfg.sifs == 16e-6, 'SIFS != 16us');
        assert(cfg.len_phy_header == 40e-6, 'PHY header != 40us');
        assert(cfg.len_trigger_frame == 100e-6, 'TF != 100us');
        assert(cfg.len_mu_back == 68e-6, 'MU-BACK != 68us');
        assert(cfg.data_rate_per_ru == 6.67e6, 'Data rate != 6.67Mbps');
        fprintf('✓\n');
        passed = passed + 1;
    catch ME
        fprintf('✗ (%s)\n', ME.message);
        failed = failed + 1;
    end
    
    %% Test 3: RU 구성
    fprintf('  [3] RU 구성 확인... ');
    try
        assert(cfg.num_ru_total == 9, 'Total RU != 9');
        assert(cfg.num_ru_ra == 1, 'RA-RU != 1');
        assert(cfg.num_ru_sa == 8, 'SA-RU != 8');
        assert(cfg.num_ru_ra + cfg.num_ru_sa == cfg.num_ru_total, 'RU 합계 불일치');
        fprintf('✓\n');
        passed = passed + 1;
    catch ME
        fprintf('✗ (%s)\n', ME.message);
        failed = failed + 1;
    end
    
    %% Test 4: MAC 파라미터
    fprintf('  [4] MAC 파라미터 확인... ');
    try
        assert(cfg.num_stas == 20, 'STA 수 != 20');
        assert(cfg.ocw_min == 7, 'OCW_min != 7');
        assert(cfg.ocw_max == 31, 'OCW_max != 31');
        assert(cfg.mpdu_size == 2000, 'MPDU != 2000 bytes');
        fprintf('✓\n');
        passed = passed + 1;
    catch ME
        fprintf('✗ (%s)\n', ME.message);
        failed = failed + 1;
    end
    
    %% Test 5: 슬롯 변환 계산
    fprintf('  [5] 슬롯 변환 계산... ');
    try
        % PHY header: 40us / 9us = 4.44 -> ceil = 5 slots
        assert(cfg.len_phy_header_slots == 5, 'PHY header slots != 5');
        % TF: 100us / 9us = 11.11 -> ceil = 12 slots
        assert(cfg.len_tf_slots == 12, 'TF slots != 12');
        % MU-BACK: 68us / 9us = 7.56 -> ceil = 8 slots
        assert(cfg.len_mu_back_slots == 8, 'MU-BACK slots != 8');
        % SIFS: 16us / 9us = 1.78 -> ceil = 2 slots
        assert(cfg.sifs_slots == 2, 'SIFS slots != 2');
        fprintf('✓\n');
        passed = passed + 1;
    catch ME
        fprintf('✗ (%s)\n', ME.message);
        failed = failed + 1;
    end
    
    %% Test 6: 데이터 전송 슬롯
    fprintf('  [6] 데이터 전송 슬롯 계산... ');
    try
        % DATA: 2000 bytes * 8 / 6.67Mbps = 2.4ms = 2400us
        % 2400us / 9us = 266.67 -> ceil = 267 slots
        expected_data_slots = ceil((cfg.mpdu_size * 8) / cfg.data_rate_per_ru / cfg.slot_duration);
        assert(cfg.data_tx_slots == expected_data_slots, 'DATA slots 불일치');
        fprintf('✓ (%d slots)\n', cfg.data_tx_slots);
        passed = passed + 1;
    catch ME
        fprintf('✗ (%s)\n', ME.message);
        failed = failed + 1;
    end
    
    %% Test 7: 프레임 교환 슬롯
    fprintf('  [7] 프레임 교환 슬롯 계산... ');
    try
        % [PHY+TF] + SIFS + [PHY+DATA] + SIFS + [PHY+BA] + SIFS
        expected = cfg.len_phy_header_slots + cfg.len_tf_slots + ...
                   cfg.sifs_slots + ...
                   cfg.len_phy_header_slots + cfg.data_tx_slots + ...
                   cfg.sifs_slots + ...
                   cfg.len_phy_header_slots + cfg.len_mu_back_slots + ...
                   cfg.sifs_slots;
        assert(cfg.frame_exchange_slots == expected, '프레임 교환 슬롯 불일치');
        fprintf('✓ (%d slots = %.1f ms)\n', cfg.frame_exchange_slots, ...
            cfg.frame_exchange_slots * cfg.slot_duration * 1000);
        passed = passed + 1;
    catch ME
        fprintf('✗ (%s)\n', ME.message);
        failed = failed + 1;
    end
end