function [passed, failed] = test_sta()
% TEST_STA: STA 클래스 테스트
%
% 테스트 항목:
%   1. STA 생성
%   2. OBO 범위 확인
%   3. 초기 상태 확인

    passed = 0;
    failed = 0;
    
    cfg = config_default();
    
    %% Test 1: STA 생성
    fprintf('  [1] STA 생성... ');
    try
        sta = STA(1, cfg);
        assert(sta.id == 1, 'STA ID 불일치');
        assert(~isempty(sta), 'STA 생성 실패');
        fprintf('✓\n');
        passed = passed + 1;
    catch ME
        fprintf('✗ (%s)\n', ME.message);
        failed = failed + 1;
    end
    
    %% Test 2: 초기 모드
    fprintf('  [2] 초기 모드 (RA)... ');
    try
        sta = STA(1, cfg);
        assert(sta.mode == 0, 'mode != 0 (RA)');
        assert(sta.associated == true, 'associated != true');
        fprintf('✓\n');
        passed = passed + 1;
    catch ME
        fprintf('✗ (%s)\n', ME.message);
        failed = failed + 1;
    end
    
    %% Test 3: OCW 초기값
    fprintf('  [3] OCW 초기값... ');
    try
        sta = STA(1, cfg);
        assert(sta.ocw == cfg.ocw_min, 'OCW != OCW_min');
        fprintf('✓ (OCW = %d)\n', sta.ocw);
        passed = passed + 1;
    catch ME
        fprintf('✗ (%s)\n', ME.message);
        failed = failed + 1;
    end
    
    %% Test 4: OBO 범위 확인 (0 ~ OCW-1)
    fprintf('  [4] OBO 범위 (0 ~ OCW-1)... ');
    try
        % 여러 STA 생성하여 OBO 분포 확인
        n_samples = 1000;
        obo_values = zeros(1, n_samples);
        for i = 1:n_samples
            sta = STA(i, cfg);
            obo_values(i) = sta.obo;
        end
        
        min_obo = min(obo_values);
        max_obo = max(obo_values);
        
        assert(min_obo >= 0, 'OBO < 0 발견');
        assert(max_obo <= cfg.ocw_min - 1, 'OBO >= OCW_min 발견');
        fprintf('✓ (range: %d ~ %d)\n', min_obo, max_obo);
        passed = passed + 1;
    catch ME
        fprintf('✗ (%s)\n', ME.message);
        failed = failed + 1;
    end
    
    %% Test 5: 큐 초기 상태
    fprintf('  [5] 큐 초기 상태... ');
    try
        sta = STA(1, cfg);
        assert(sta.queue_size == 0, 'queue_size != 0');
        assert(sta.queue_packets == 0, 'queue_packets != 0');
        fprintf('✓\n');
        passed = passed + 1;
    catch ME
        fprintf('✗ (%s)\n', ME.message);
        failed = failed + 1;
    end
    
    %% Test 6: T_hold 초기 상태
    fprintf('  [6] T_hold 초기 상태... ');
    try
        sta = STA(1, cfg);
        assert(sta.thold_active == false, 'thold_active != false');
        assert(sta.thold_expiry == 0, 'thold_expiry != 0');
        fprintf('✓\n');
        passed = passed + 1;
    catch ME
        fprintf('✗ (%s)\n', ME.message);
        failed = failed + 1;
    end
    
    %% Test 7: 통계 초기 상태
    fprintf('  [7] 통계 초기 상태... ');
    try
        sta = STA(1, cfg);
        assert(sta.tx_success == 0, 'tx_success != 0');
        assert(sta.tx_collision == 0, 'tx_collision != 0');
        assert(sta.tx_bytes == 0, 'tx_bytes != 0');
        fprintf('✓\n');
        passed = passed + 1;
    catch ME
        fprintf('✗ (%s)\n', ME.message);
        failed = failed + 1;
    end
    
    %% Test 8: 여러 STA 생성
    fprintf('  [8] 다중 STA 생성... ');
    try
        n_stas = cfg.num_stas;
        stas = STA.empty(0, n_stas);
        for i = 1:n_stas
            stas(i) = STA(i, cfg);
        end
        assert(length(stas) == n_stas, 'STA 수 불일치');
        
        % ID 확인
        for i = 1:n_stas
            assert(stas(i).id == i, 'STA ID 순서 불일치');
        end
        fprintf('✓ (%d STAs)\n', n_stas);
        passed = passed + 1;
    catch ME
        fprintf('✗ (%s)\n', ME.message);
        failed = failed + 1;
    end
end