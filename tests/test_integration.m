function [passed, failed] = test_integration()
% TEST_INTEGRATION: 전체 시뮬레이션 통합 테스트
%
% 테스트 항목:
%   1. 짧은 시뮬레이션 실행
%   2. 결과 구조체 확인
%   3. 기본 메트릭 범위 확인

    passed = 0;
    failed = 0;
    
    %% Test 1: 짧은 시뮬레이션 실행
    fprintf('  [1] 짧은 시뮬레이션 실행 (1초)... ');
    try
        cfg = config_default();
        cfg.simulation_time = 1.0;  % 1초로 단축
        cfg.warmup_time = 0.1;
        cfg.verbose = 0;  % 출력 끄기
        
        tic;
        results = run_simulation(cfg);
        elapsed = toc;
        
        assert(~isempty(results), '결과가 비어있음');
        fprintf('✓ (%.2fs)\n', elapsed);
        passed = passed + 1;
    catch ME
        fprintf('✗ (%s)\n', ME.message);
        failed = failed + 1;
        return;  % 기본 테스트 실패 시 중단
    end
    
    %% Test 2: 결과 구조체 필드 확인
    fprintf('  [2] 결과 구조체 필드... ');
    try
        required_fields = {'packets', 'delay', 'throughput', 'uora', 'bsr', 'fairness'};
        for i = 1:length(required_fields)
            assert(isfield(results, required_fields{i}), ...
                sprintf('필드 누락: %s', required_fields{i}));
        end
        fprintf('✓\n');
        passed = passed + 1;
    catch ME
        fprintf('✗ (%s)\n', ME.message);
        failed = failed + 1;
    end
    
    %% Test 3: 패킷 통계
    fprintf('  [3] 패킷 통계... ');
    try
        assert(results.packets.generated >= 0, 'generated < 0');
        assert(results.packets.completed >= 0, 'completed < 0');
        assert(results.packets.completed <= results.packets.generated, ...
            'completed > generated');
        
        if results.packets.generated > 0
            assert(results.packets.completion_rate >= 0 && ...
                   results.packets.completion_rate <= 1, 'completion_rate 범위 오류');
        end
        fprintf('✓ (gen=%d, comp=%d)\n', results.packets.generated, results.packets.completed);
        passed = passed + 1;
    catch ME
        fprintf('✗ (%s)\n', ME.message);
        failed = failed + 1;
    end
    
    %% Test 4: 지연 통계
    fprintf('  [4] 지연 통계... ');
    try
        if results.packets.completed > 0
            assert(results.delay.mean_ms >= 0, 'mean_ms < 0');
            assert(results.delay.p90_ms >= results.delay.mean_ms * 0.5, 'p90 너무 작음');
            assert(results.delay.max_ms >= results.delay.p90_ms, 'max < p90');
        end
        fprintf('✓ (mean=%.2fms, p90=%.2fms)\n', results.delay.mean_ms, results.delay.p90_ms);
        passed = passed + 1;
    catch ME
        fprintf('✗ (%s)\n', ME.message);
        failed = failed + 1;
    end
    
    %% Test 5: UORA 통계
    fprintf('  [5] UORA 통계... ');
    try
        total_rate = results.uora.success_rate + results.uora.collision_rate + results.uora.idle_rate;
        % 약간의 오차 허용 (반올림)
        assert(abs(total_rate - 1.0) < 0.01 || total_rate == 0, ...
            'UORA 비율 합 != 1');
        fprintf('✓ (success=%.1f%%, collision=%.1f%%)\n', ...
            results.uora.success_rate * 100, results.uora.collision_rate * 100);
        passed = passed + 1;
    catch ME
        fprintf('✗ (%s)\n', ME.message);
        failed = failed + 1;
    end
    
    %% Test 6: T_hold 통계 (활성화된 경우)
    fprintf('  [6] T_hold 통계... ');
    try
        if cfg.thold_enabled
            assert(isfield(results, 'thold'), 'thold 필드 누락');
            assert(results.thold.activations >= 0, 'activations < 0');
            assert(results.thold.hits >= 0, 'hits < 0');
            assert(results.thold.hit_rate >= 0 && results.thold.hit_rate <= 1, ...
                'hit_rate 범위 오류');
            fprintf('✓ (activations=%d, hits=%d)\n', results.thold.activations, results.thold.hits);
        else
            fprintf('✓ (비활성화)\n');
        end
        passed = passed + 1;
    catch ME
        fprintf('✗ (%s)\n', ME.message);
        failed = failed + 1;
    end
    
    %% Test 7: Fairness Index
    fprintf('  [7] Fairness Index (Jain)... ');
    try
        assert(results.fairness.jain_index >= 0 && results.fairness.jain_index <= 1, ...
            'Jain Index 범위 오류');
        fprintf('✓ (%.4f)\n', results.fairness.jain_index);
        passed = passed + 1;
    catch ME
        fprintf('✗ (%s)\n', ME.message);
        failed = failed + 1;
    end
    
    %% Test 8: TF 카운트
    fprintf('  [8] TF 카운트... ');
    try
        assert(results.tf_count > 0, 'tf_count == 0');
        expected_tf = cfg.simulation_time / (cfg.frame_exchange_slots * cfg.slot_duration);
        ratio = results.tf_count / expected_tf;
        assert(ratio > 0.8 && ratio < 1.2, 'TF 카운트 비정상');
        fprintf('✓ (%d TFs)\n', results.tf_count);
        passed = passed + 1;
    catch ME
        fprintf('✗ (%s)\n', ME.message);
        failed = failed + 1;
    end
    
    %% Test 9: T_hold 비활성화 시뮬레이션
    fprintf('  [9] T_hold 비활성화 시뮬레이션... ');
    try
        cfg2 = config_default();
        cfg2.simulation_time = 0.5;
        cfg2.warmup_time = 0.05;
        cfg2.verbose = 0;
        cfg2.thold_enabled = false;
        
        results2 = run_simulation(cfg2);
        
        assert(~isempty(results2), '결과가 비어있음');
        fprintf('✓\n');
        passed = passed + 1;
    catch ME
        fprintf('✗ (%s)\n', ME.message);
        failed = failed + 1;
    end
    
    %% Test 10: 재현성 (같은 시드)
    fprintf('  [10] 재현성 (같은 시드)... ');
    try
        cfg3 = config_default();
        cfg3.simulation_time = 0.5;
        cfg3.warmup_time = 0.05;
        cfg3.verbose = 0;
        cfg3.seed = 9999;
        
        results3a = run_simulation(cfg3);
        results3b = run_simulation(cfg3);
        
        % 같은 시드면 같은 결과
        assert(results3a.packets.generated == results3b.packets.generated, '재현성 실패');
        fprintf('✓\n');
        passed = passed + 1;
    catch ME
        fprintf('✗ (%s)\n', ME.message);
        failed = failed + 1;
    end
end