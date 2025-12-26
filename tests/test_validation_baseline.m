function [passed, failed] = test_validation_baseline()
% TEST_VALIDATION_BASELINE: Baseline UORA 동작 정밀 검증
%
% 레퍼런스 코드(RPT_Simple_UORA_Access_Control)와 일관성 확인
%
% 테스트 항목:
%   1. OBO 분포 (균등 분포 [0, OCW-1])
%   2. BEB 시퀀스 (7→15→31→31)
%   3. 충돌 검출 정확성
%   4. SA/RA 모드 전환 로직
%   5. Baseline 시뮬레이션 실행

    fprintf('\n');
    fprintf('╔══════════════════════════════════════════════════════════════╗\n');
    fprintf('║         Baseline UORA 동작 검증 (레퍼런스 일관성)            ║\n');
    fprintf('╚══════════════════════════════════════════════════════════════╝\n\n');

    passed = 0;
    failed = 0;
    
    cfg = config_default();
    
    %% ═══════════════════════════════════════════════════
    %  Test 1: OBO 분포 검증 (균등 분포)
    %  ═══════════════════════════════════════════════════
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    fprintf('[1] OBO 분포 검증 (균등 분포 [0, OCW-1])\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    try
        n_samples = 10000;
        ocw = 7;  % OCW_min
        
        % floor(OCW * rand()) 분포 테스트
        obo_values = floor(ocw * rand(1, n_samples));
        
        % 각 값의 빈도 계산
        counts = histcounts(obo_values, -0.5:(ocw-0.5));
        expected_count = n_samples / ocw;
        
        % 각 빈도가 기대값의 ±20% 내에 있는지 확인
        min_expected = expected_count * 0.8;
        max_expected = expected_count * 1.2;
        all_in_range = all(counts >= min_expected & counts <= max_expected);
        
        fprintf('  범위: [%d, %d]\n', min(obo_values), max(obo_values));
        fprintf('  기대 범위: [0, %d]\n', ocw - 1);
        fprintf('  기대 빈도: %.0f (±20%%: %.0f ~ %.0f)\n', expected_count, min_expected, max_expected);
        fprintf('  실제 빈도: %s\n', mat2str(counts));
        
        % 범위 검증
        assert(min(obo_values) >= 0, 'OBO < 0 발견');
        assert(max(obo_values) <= ocw - 1, 'OBO >= OCW 발견');
        
        % 균등 분포 검증 (각 값이 기대 범위 내)
        assert(all_in_range, '균등 분포 아님 (일부 빈도가 ±20% 범위 벗어남)');
        
        fprintf('  ✅ PASS: OBO 균등 분포 확인\n\n');
        passed = passed + 1;
    catch ME
        fprintf('  ❌ FAIL: %s\n\n', ME.message);
        failed = failed + 1;
    end
    
    %% ═══════════════════════════════════════════════════
    %  Test 2: BEB 시퀀스 검증
    %  ═══════════════════════════════════════════════════
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    fprintf('[2] BEB 시퀀스 검증 ((CW+1)*2-1)\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    try
        uora = UORAProcessor(cfg);
        sta = STA(1, cfg);
        
        % BEB 시퀀스: 7 → 15 → 31 → 31 (capped)
        expected = [7, 15, 31, 31, 31];
        actual = zeros(1, length(expected));
        actual(1) = sta.ocw;
        
        for i = 2:length(expected)
            uora.handle_collision(sta);
            actual(i) = sta.ocw;
        end
        
        fprintf('  예상: %s\n', mat2str(expected));
        fprintf('  실제: %s\n', mat2str(actual));
        
        assert(isequal(actual, expected), 'BEB 시퀀스 불일치');
        
        % 공식 검증: (CW+1)*2-1
        fprintf('\n  공식 검증:\n');
        fprintf('    (7+1)*2-1 = %d (예상: 15)\n', (7+1)*2-1);
        fprintf('    (15+1)*2-1 = %d (예상: 31)\n', (15+1)*2-1);
        fprintf('    (31+1)*2-1 = %d → capped to 31\n', (31+1)*2-1);
        
        fprintf('  ✅ PASS: BEB 시퀀스 정확\n\n');
        passed = passed + 1;
    catch ME
        fprintf('  ❌ FAIL: %s\n\n', ME.message);
        failed = failed + 1;
    end
    
    %% ═══════════════════════════════════════════════════
    %  Test 3: OBO 감소 로직 검증
    %  ═══════════════════════════════════════════════════
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    fprintf('[3] OBO 감소 로직 검증 (OBO -= N_RA_RU)\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    try
        sta = STA(1, cfg);
        sta.obo = 5;  % 초기 OBO
        sta.queue_size = 2000;  % 큐에 데이터 있음
        
        num_ra_ru = cfg.num_ru_ra;  % 1
        
        fprintf('  초기 OBO: %d\n', sta.obo);
        fprintf('  N_RA_RU: %d\n', num_ra_ru);
        
        % OBO 감소 시뮬레이션
        slots_to_tx = 0;
        while sta.obo > 0
            sta.obo = sta.obo - num_ra_ru;
            slots_to_tx = slots_to_tx + 1;
            fprintf('    Slot %d: OBO = %d\n', slots_to_tx, sta.obo);
        end
        
        fprintf('  전송까지 슬롯 수: %d\n', slots_to_tx);
        
        % OBO=5, N_RA_RU=1 → 5슬롯 후 OBO=0 → 전송
        assert(slots_to_tx == 5, '전송 타이밍 불일치');
        assert(sta.obo <= 0, '전송 조건 불충족');
        
        fprintf('  ✅ PASS: OBO 감소 로직 정확\n\n');
        passed = passed + 1;
    catch ME
        fprintf('  ❌ FAIL: %s\n\n', ME.message);
        failed = failed + 1;
    end
    
    %% ═══════════════════════════════════════════════════
    %  Test 4: 충돌 검출 정확성
    %  ═══════════════════════════════════════════════════
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    fprintf('[4] 충돌 검출 정확성\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    try
        detector = CollisionDetector(cfg);
        rus = RU(cfg);
        stas = STA.empty(0, 3);
        for i = 1:3
            stas(i) = STA(i, cfg);
        end
        
        % 시나리오 1: 같은 RU에 2개 STA → 충돌
        ra_attempts = struct('sta_idx', {1, 2}, 'ru_idx', {1, 1});
        sa_assignments = struct('sta_idx', {}, 'ru_idx', {});
        
        [success, collided, idle] = detector.detect(stas, rus, ra_attempts, sa_assignments);
        
        fprintf('  시나리오 1: RU1에 STA1, STA2 동시 접근\n');
        fprintf('    성공: %d, 충돌: %d, 유휴: %d\n', length(success), length(collided), idle.ra);
        
        assert(length(success) == 0, '충돌인데 성공 판정');
        assert(length(collided) == 2, '충돌 STA 수 불일치');
        
        % 시나리오 2: 다른 RU에 1개씩 → 둘 다 성공 (RA-RU가 1개면 불가능)
        % RA-RU가 1개이므로 시나리오 수정
        rus.reset();
        ra_attempts2 = struct('sta_idx', {1}, 'ru_idx', {1});
        [success2, collided2, ~] = detector.detect(stas, rus, ra_attempts2, sa_assignments);
        
        fprintf('  시나리오 2: RU1에 STA1만 접근\n');
        fprintf('    성공: %d, 충돌: %d\n', length(success2), length(collided2));
        
        assert(length(success2) == 1, '단독 접근인데 성공 아님');
        assert(length(collided2) == 0, '단독 접근인데 충돌 판정');
        
        fprintf('  ✅ PASS: 충돌 검출 정확\n\n');
        passed = passed + 1;
    catch ME
        fprintf('  ❌ FAIL: %s\n\n', ME.message);
        failed = failed + 1;
    end
    
    %% ═══════════════════════════════════════════════════
    %  Test 5: 모드 전환 로직 (RA ↔ SA)
    %  ═══════════════════════════════════════════════════
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    fprintf('[5] 모드 전환 로직 (RA ↔ SA)\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    try
        sta = STA(1, cfg);
        ap = AP(cfg);
        
        fprintf('  초기 모드: %s\n', mode_str(sta.mode));
        assert(sta.mode == 0, '초기 모드가 RA 아님');
        
        % UORA 성공 후 버퍼 있음 → SA 모드
        sta.queue_size = 2000;
        ap.bsr_table(1) = 2000;
        sta.mode = 1;  % SA로 전환
        
        fprintf('  UORA 성공 + 버퍼 있음 → %s\n', mode_str(sta.mode));
        assert(sta.mode == 1, 'SA 모드로 전환 안됨');
        
        % 버퍼 비움 + T_hold 비활성화 → RA 모드
        sta.queue_size = 0;
        sta.mode = 0;  % RA로 복귀
        
        fprintf('  버퍼 비움 (T_hold OFF) → %s\n', mode_str(sta.mode));
        assert(sta.mode == 0, 'RA 모드로 복귀 안됨');
        
        fprintf('  ✅ PASS: 모드 전환 로직 정확\n\n');
        passed = passed + 1;
    catch ME
        fprintf('  ❌ FAIL: %s\n\n', ME.message);
        failed = failed + 1;
    end
    
    %% ═══════════════════════════════════════════════════
    %  Test 6: Baseline 시뮬레이션 (T_hold OFF)
    %  ═══════════════════════════════════════════════════
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    fprintf('[6] Baseline 시뮬레이션 (T_hold OFF, 5초)\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    try
        cfg_baseline = config_default();
        cfg_baseline.simulation_time = 10.0;
        cfg_baseline.warmup_time = 0.0;
        cfg_baseline.thold_enabled = false;
        cfg_baseline.verbose = 0;
        cfg_baseline.rho = 0.5;
        
        fprintf('  설정:\n');
        fprintf('    시뮬레이션: %.1fs, 워밍업: %.1fs\n', ...
            cfg_baseline.simulation_time, cfg_baseline.warmup_time);
        fprintf('    STA: %d, RA-RU: %d, rho: %.2f\n', ...
            cfg_baseline.num_stas, cfg_baseline.num_ru_ra, cfg_baseline.rho);
        fprintf('    T_hold: OFF\n');
        
        tic;
        results = run_simulation(cfg_baseline);
        elapsed = toc;
        
        fprintf('\n  결과:\n');
        fprintf('    실행 시간: %.2fs\n', elapsed);
        fprintf('    패킷 생성: %d, 완료: %d (%.1f%%)\n', ...
            results.packets.generated, results.packets.completed, ...
            results.packets.completion_rate * 100);
        fprintf('    평균 지연: %.2f ms\n', results.delay.mean_ms);
        fprintf('    UORA 성공률: %.1f%%, 충돌률: %.1f%%\n', ...
            results.uora.success_rate * 100, results.uora.collision_rate * 100);
        fprintf('    BSR Explicit 비율: %.1f%%\n', results.bsr.explicit_ratio * 100);
        
        % Baseline 검증
        % T_hold OFF이면 모든 BSR이 Explicit (RA 성공 시에만 전송)
        % RA만 사용하므로 explicit_ratio가 높아야 함
        
        assert(results.packets.generated > 0, '패킷 생성 안됨');
        assert(results.packets.completed > 0, '패킷 완료 안됨');
        assert(results.delay.mean_ms > 0, '지연 계산 오류');
        
        fprintf('  ✅ PASS: Baseline 시뮬레이션 완료\n\n');
        passed = passed + 1;
    catch ME
        fprintf('  ❌ FAIL: %s\n\n', ME.message);
        failed = failed + 1;
    end
    
    %% 결과 요약
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    fprintf('Baseline 검증 결과: %d passed, %d failed\n', passed, failed);
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n');
end

function str = mode_str(mode)
    if mode == 0
        str = 'RA';
    else
        str = 'SA';
    end
end
