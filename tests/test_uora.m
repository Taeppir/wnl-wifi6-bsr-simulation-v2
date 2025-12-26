function [passed, failed] = test_uora()
% TEST_UORA: UORAProcessor 테스트
%
% 테스트 항목:
%   1. UORA 프로세서 생성
%   2. OBO 감소 로직
%   3. BEB (Binary Exponential Backoff)
%   4. 성공 시 OCW 리셋

    passed = 0;
    failed = 0;
    
    cfg = config_default();
    
    %% Test 1: UORA 프로세서 생성
    fprintf('  [1] UORA 프로세서 생성... ');
    try
        uora = UORAProcessor(cfg);
        assert(uora.num_ra_ru == cfg.num_ru_ra, 'num_ra_ru 불일치');
        assert(uora.ocw_min == cfg.ocw_min, 'ocw_min 불일치');
        assert(uora.ocw_max == cfg.ocw_max, 'ocw_max 불일치');
        fprintf('✓\n');
        passed = passed + 1;
    catch ME
        fprintf('✗ (%s)\n', ME.message);
        failed = failed + 1;
    end
    
    %% Test 2: 충돌 시 BEB - OCW 증가
    fprintf('  [2] BEB: OCW 증가 ((CW+1)*2-1)... ');
    try
        uora = UORAProcessor(cfg);
        sta = STA(1, cfg);
        
        % 초기 OCW = 7
        initial_ocw = sta.ocw;
        assert(initial_ocw == 7, '초기 OCW != 7');
        
        % 충돌 발생
        uora.handle_collision(sta);
        
        % OCW = (7+1)*2 - 1 = 15
        expected_ocw = (initial_ocw + 1) * 2 - 1;
        assert(sta.ocw == expected_ocw, 'OCW != 15 after collision');
        fprintf('✓ (%d -> %d)\n', initial_ocw, sta.ocw);
        passed = passed + 1;
    catch ME
        fprintf('✗ (%s)\n', ME.message);
        failed = failed + 1;
    end
    
    %% Test 3: BEB - OCW 최대값 제한
    fprintf('  [3] BEB: OCW 최대값 제한... ');
    try
        uora = UORAProcessor(cfg);
        sta = STA(1, cfg);
        
        % OCW를 최대값 근처로 설정
        sta.ocw = 31;
        
        % 충돌 발생
        uora.handle_collision(sta);
        
        % OCW_max = 31을 초과하면 안됨
        assert(sta.ocw == cfg.ocw_max, 'OCW > OCW_max');
        fprintf('✓ (capped at %d)\n', sta.ocw);
        passed = passed + 1;
    catch ME
        fprintf('✗ (%s)\n', ME.message);
        failed = failed + 1;
    end
    
    %% Test 4: 성공 시 OCW 리셋
    fprintf('  [4] 성공 시 OCW 리셋... ');
    try
        uora = UORAProcessor(cfg);
        sta = STA(1, cfg);
        
        % OCW를 높은 값으로 설정
        sta.ocw = 31;
        
        % 성공 처리
        uora.handle_success(sta);
        
        % OCW = OCW_min으로 리셋
        assert(sta.ocw == cfg.ocw_min, 'OCW != OCW_min after success');
        fprintf('✓ (reset to %d)\n', sta.ocw);
        passed = passed + 1;
    catch ME
        fprintf('✗ (%s)\n', ME.message);
        failed = failed + 1;
    end
    
    %% Test 5: 충돌 후 OBO 범위
    fprintf('  [5] 충돌 후 OBO 범위 (0 ~ OCW-1)... ');
    try
        uora = UORAProcessor(cfg);
        
        n_samples = 1000;
        obo_values = zeros(1, n_samples);
        
        for i = 1:n_samples
            sta = STA(i, cfg);
            sta.ocw = 15;  % 고정된 OCW로 테스트
            uora.handle_collision(sta);
            obo_values(i) = sta.obo;
        end
        
        % 충돌 후 OCW = (15+1)*2-1 = 31
        expected_ocw = 31;
        
        min_obo = min(obo_values);
        max_obo = max(obo_values);
        
        assert(min_obo >= 0, 'OBO < 0');
        assert(max_obo <= expected_ocw - 1, 'OBO >= OCW');
        fprintf('✓ (range: %d ~ %d, OCW=%d)\n', min_obo, max_obo, expected_ocw);
        passed = passed + 1;
    catch ME
        fprintf('✗ (%s)\n', ME.message);
        failed = failed + 1;
    end
    
    %% Test 6: 성공 후 OBO 범위
    fprintf('  [6] 성공 후 OBO 범위 (0 ~ OCW_min-1)... ');
    try
        uora = UORAProcessor(cfg);
        
        n_samples = 1000;
        obo_values = zeros(1, n_samples);
        
        for i = 1:n_samples
            sta = STA(i, cfg);
            sta.ocw = 31;  % 높은 OCW에서 시작
            uora.handle_success(sta);
            obo_values(i) = sta.obo;
        end
        
        min_obo = min(obo_values);
        max_obo = max(obo_values);
        
        assert(min_obo >= 0, 'OBO < 0');
        assert(max_obo <= cfg.ocw_min - 1, 'OBO >= OCW_min');
        fprintf('✓ (range: %d ~ %d)\n', min_obo, max_obo);
        passed = passed + 1;
    catch ME
        fprintf('✗ (%s)\n', ME.message);
        failed = failed + 1;
    end
    
    %% Test 7: BEB 시퀀스 확인
    fprintf('  [7] BEB 시퀀스 (7->15->31->31)... ');
    try
        uora = UORAProcessor(cfg);
        sta = STA(1, cfg);
        
        expected_sequence = [7, 15, 31, 31];  % OCW_max = 31
        
        assert(sta.ocw == expected_sequence(1), '초기 OCW 불일치');
        
        for i = 2:length(expected_sequence)
            uora.handle_collision(sta);
            assert(sta.ocw == expected_sequence(i), ...
                sprintf('Step %d: OCW=%d, expected=%d', i, sta.ocw, expected_sequence(i)));
        end
        fprintf('✓\n');
        passed = passed + 1;
    catch ME
        fprintf('✗ (%s)\n', ME.message);
        failed = failed + 1;
    end
    
    %% Test 8: 상태 플래그 리셋
    fprintf('  [8] 상태 플래그 리셋... ');
    try
        uora = UORAProcessor(cfg);
        sta = STA(1, cfg);
        
        % 전송 시도 상태로 설정
        sta.attempting = true;
        sta.selected_ru = 3;
        
        % 성공 처리
        uora.handle_success(sta);
        
        assert(sta.attempting == false, 'attempting != false');
        assert(sta.selected_ru == 0, 'selected_ru != 0');
        fprintf('✓\n');
        passed = passed + 1;
    catch ME
        fprintf('✗ (%s)\n', ME.message);
        failed = failed + 1;
    end
end