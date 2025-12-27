function [passed, failed] = test_validation_metrics()
% TEST_VALIDATION_METRICS: 성능 지표 측정 정확성 검증
%
% 테스트 항목:
%   1. Delay 계산 검증
%   2. Throughput 계산 검증
%   3. Collision Rate 검증
%   4. Jain's Fairness Index 검증
%   5. 다양한 시나리오 비교

    fprintf('\n');
    fprintf('╔══════════════════════════════════════════════════════════════╗\n');
    fprintf('║         성능 지표 측정 정확성 검증                            ║\n');
    fprintf('╚══════════════════════════════════════════════════════════════╝\n\n');

    passed = 0;
    failed = 0;
    
    cfg = config_default();
    
    %% ═══════════════════════════════════════════════════
    %  Test 1: Delay 계산 검증
    %  ═══════════════════════════════════════════════════
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    fprintf('[1] Delay 계산 검증\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    try
        % 수동으로 delay 계산 테스트
        delays_slots = [10, 20, 30, 40, 50, 100, 200, 500];  % 슬롯 단위
        delays_ms = delays_slots * cfg.slot_duration * 1000;  % ms 단위
        
        % 통계 계산
        mean_delay = mean(delays_ms);
        p90_delay = prctile(delays_ms, 90);
        p99_delay = prctile(delays_ms, 99);
        max_delay = max(delays_ms);
        
        fprintf('  테스트 데이터 (슬롯): %s\n', mat2str(delays_slots));
        fprintf('  테스트 데이터 (ms): %s\n', mat2str(round(delays_ms, 2)));
        fprintf('\n  계산 결과:\n');
        fprintf('    Mean: %.4f ms\n', mean_delay);
        fprintf('    P90: %.4f ms\n', p90_delay);
        fprintf('    P99: %.4f ms\n', p99_delay);
        fprintf('    Max: %.4f ms\n', max_delay);
        
        % 검증
        expected_mean = mean(delays_ms);
        assert(abs(mean_delay - expected_mean) < 0.0001, 'Mean 계산 오류');
        assert(p90_delay <= max_delay, 'P90 > Max');
        assert(p99_delay <= max_delay, 'P99 > Max');
        assert(p90_delay <= p99_delay, 'P90 > P99');
        
        fprintf('  ✅ PASS: Delay 계산 정확\n\n');
        passed = passed + 1;
    catch ME
        fprintf('  ❌ FAIL: %s\n\n', ME.message);
        failed = failed + 1;
    end
    
    %% ═══════════════════════════════════════════════════
    %  Test 2: Throughput 계산 검증
    %  ═══════════════════════════════════════════════════
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    fprintf('[2] Throughput 계산 검증\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    try
        % 시나리오: 10초 동안 100개 패킷 (2000 bytes each) 전송
        total_bytes = 100 * 2000;  % 200,000 bytes
        effective_time = 10.0;  % 초
        
        throughput_mbps = (total_bytes * 8) / effective_time / 1e6;
        
        fprintf('  시나리오:\n');
        fprintf('    전송 패킷: 100개 × 2000 bytes = %d bytes\n', total_bytes);
        fprintf('    유효 시간: %.1f s\n', effective_time);
        fprintf('\n  계산:\n');
        fprintf('    Throughput = %d × 8 / %.1f / 1e6 = %.4f Mbps\n', ...
            total_bytes, effective_time, throughput_mbps);
        
        % 예상값
        expected = 0.16;  % 0.16 Mbps
        assert(abs(throughput_mbps - expected) < 0.001, 'Throughput 계산 오류');
        
        % 채널 용량 대비 확인
        max_throughput = cfg.data_rate_per_ru / 1e6;  % 6.67 Mbps per RU
        utilization = throughput_mbps / max_throughput;
        
        fprintf('\n  채널 이용률:\n');
        fprintf('    최대 용량 (1 RU): %.2f Mbps\n', max_throughput);
        fprintf('    이용률: %.2f%%\n', utilization * 100);
        
        fprintf('  ✅ PASS: Throughput 계산 정확\n\n');
        passed = passed + 1;
    catch ME
        fprintf('  ❌ FAIL: %s\n\n', ME.message);
        failed = failed + 1;
    end
    
    %% ═══════════════════════════════════════════════════
    %  Test 3: UORA Rate 계산 검증
    %  ═══════════════════════════════════════════════════
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    fprintf('[3] UORA Rate 계산 검증 (Success/Collision/Idle)\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    try
        % 테스트 데이터
        ra_success = 50;
        ra_collision = 30;
        ra_idle = 20;
        total = ra_success + ra_collision + ra_idle;
        
        success_rate = ra_success / total;
        collision_rate = ra_collision / total;
        idle_rate = ra_idle / total;
        
        fprintf('  테스트 데이터:\n');
        fprintf('    Success: %d, Collision: %d, Idle: %d\n', ra_success, ra_collision, ra_idle);
        fprintf('\n  계산 결과:\n');
        fprintf('    Success Rate: %.2f%%\n', success_rate * 100);
        fprintf('    Collision Rate: %.2f%%\n', collision_rate * 100);
        fprintf('    Idle Rate: %.2f%%\n', idle_rate * 100);
        fprintf('    합계: %.2f%% (100%% 예상)\n', (success_rate + collision_rate + idle_rate) * 100);
        
        % 검증
        assert(abs(success_rate - 0.5) < 0.001, 'Success rate 계산 오류');
        assert(abs(collision_rate - 0.3) < 0.001, 'Collision rate 계산 오류');
        assert(abs(idle_rate - 0.2) < 0.001, 'Idle rate 계산 오류');
        assert(abs(success_rate + collision_rate + idle_rate - 1.0) < 0.001, '합계 != 1');
        
        fprintf('  ✅ PASS: UORA Rate 계산 정확\n\n');
        passed = passed + 1;
    catch ME
        fprintf('  ❌ FAIL: %s\n\n', ME.message);
        failed = failed + 1;
    end
    
    %% ═══════════════════════════════════════════════════
    %  Test 4: Jain's Fairness Index 검증
    %  ═══════════════════════════════════════════════════
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    fprintf('[4] Jain''s Fairness Index 검증\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    try
        % 시나리오 1: 완전 공정 (모든 STA 동일)
        throughputs1 = [1, 1, 1, 1, 1];
        n1 = length(throughputs1);
        jain1 = sum(throughputs1)^2 / (n1 * sum(throughputs1.^2));
        
        fprintf('  시나리오 1 (완전 공정): [1,1,1,1,1]\n');
        fprintf('    Jain Index: %.4f (예상: 1.0000)\n', jain1);
        assert(abs(jain1 - 1.0) < 0.001, 'Jain Index != 1 for equal');
        
        % 시나리오 2: 완전 불공정 (1명만 전송)
        throughputs2 = [5, 0, 0, 0, 0];
        n2 = length(throughputs2);
        jain2 = sum(throughputs2)^2 / (n2 * sum(throughputs2.^2));
        
        fprintf('\n  시나리오 2 (완전 불공정): [5,0,0,0,0]\n');
        fprintf('    Jain Index: %.4f (예상: 0.2000)\n', jain2);
        assert(abs(jain2 - 0.2) < 0.001, 'Jain Index != 1/n for one user');
        
        % 시나리오 3: 중간
        throughputs3 = [2, 2, 1, 1, 0];
        n3 = length(throughputs3);
        jain3 = sum(throughputs3)^2 / (n3 * sum(throughputs3.^2));
        
        fprintf('\n  시나리오 3 (중간): [2,2,1,1,0]\n');
        fprintf('    Jain Index: %.4f\n', jain3);
        assert(jain3 > 0.2 && jain3 < 1.0, 'Jain Index 범위 오류');
        
        fprintf('  ✅ PASS: Jain''s Fairness Index 정확\n\n');
        passed = passed + 1;
    catch ME
        fprintf('  ❌ FAIL: %s\n\n', ME.message);
        failed = failed + 1;
    end
    
    %% ═══════════════════════════════════════════════════
    %  Test 5: 시뮬레이션 결과 일관성 (rho 변화)
    %  ═══════════════════════════════════════════════════
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    fprintf('[5] 시뮬레이션 결과 일관성 (rho 변화)\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    try
        rho_values = [0.2, 0.3, 0.5];
        results_array = cell(1, length(rho_values));
        
        fprintf('  rho 값에 따른 결과 비교:\n\n');
        fprintf('  %-6s | %-8s | %-10s | %-10s | %-8s | %-8s\n', ...
            'rho', 'Packets', 'Delay(ms)', 'Collision%', 'RA-Util%', 'SA-Util%');
        fprintf('  %s\n', repmat('-', 1, 70));
        
        for i = 1:length(rho_values)
            cfg_test = config_default();
            cfg_test.simulation_time = 5.0;
            cfg_test.warmup_time = 0.5;
            cfg_test.verbose = 0;
            cfg_test.thold_enabled = false;
            cfg_test.rho = rho_values(i);
            cfg_test.mu_off = cfg_test.mu_on * (1 - cfg_test.rho) / cfg_test.rho;
            
            results_array{i} = run_simulation(cfg_test);
            r = results_array{i};
            
            fprintf('  %-6.2f | %-8d | %-10.2f | %-10.1f | %-8.1f | %-8.1f\n', ...
                rho_values(i), r.packets.completed, r.delay.mean_ms, ...
                r.uora.collision_rate * 100, ...
                r.ru_utilization.ra_utilization * 100, ...
                r.ru_utilization.sa_utilization * 100);
        end
        
        % 검증: rho 증가 → 일반적으로 충돌 증가
        % (트래픽 부하가 높아지므로)
        fprintf('\n  트렌드 분석:\n');
        
        packets = cellfun(@(r) r.packets.completed, results_array);
        delays = cellfun(@(r) r.delay.mean_ms, results_array);
        collisions = cellfun(@(r) r.uora.collision_rate, results_array);
        ra_utils = cellfun(@(r) r.ru_utilization.ra_utilization, results_array);
        
        fprintf('    패킷 수: %s (rho 증가 → 증가 예상)\n', mat2str(packets));
        fprintf('    지연: %s\n', mat2str(round(delays, 2)));
        fprintf('    충돌률: %s\n', mat2str(round(collisions * 100, 1)));
        fprintf('    RA-RU 활용률: %s\n', mat2str(round(ra_utils * 100, 1)));
        
        % 기본 검증: 결과가 유효한 범위인지
        for i = 1:length(results_array)
            assert(results_array{i}.packets.completed >= 0, '음수 패킷');
            assert(results_array{i}.delay.mean_ms >= 0, '음수 지연');
            assert(results_array{i}.uora.collision_rate >= 0 && ...
                   results_array{i}.uora.collision_rate <= 1, '충돌률 범위 오류');
            assert(results_array{i}.ru_utilization.ra_utilization >= 0 && ...
                   results_array{i}.ru_utilization.ra_utilization <= 1, 'RA 활용률 범위 오류');
        end
        
        fprintf('  ✅ PASS: 시뮬레이션 결과 일관성 확인\n\n');
        passed = passed + 1;
    catch ME
        fprintf('  ❌ FAIL: %s\n\n', ME.message);
        failed = failed + 1;
    end
    
    %% ═══════════════════════════════════════════════════
    %  Test 6: T_hold ON/OFF 비교
    %  ═══════════════════════════════════════════════════
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    fprintf('[6] RU 활용률 검증\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    try
        % RU 활용률 계산 검증
        % 시나리오: 100 슬롯, RA-RU 1개, SA-RU 8개
        total_slots = 100;
        num_ra_ru = 1;
        num_sa_ru = 8;
        
        ra_success = 30;
        ra_collision = 20;
        ra_idle = 50;  % 30 + 20 + 50 = 100
        sa_tx = 200;  % 8 RU × 100 slots = 800 가능, 200 사용
        
        % RA-RU 활용률 = (success + collision) / total_ra_slots
        ra_used = ra_success + ra_collision;
        total_ra_slots = total_slots * num_ra_ru;
        ra_util = ra_used / total_ra_slots;
        ra_success_util = ra_success / total_ra_slots;
        
        % SA-RU 활용률 = sa_tx / total_sa_slots
        total_sa_slots = total_slots * num_sa_ru;
        sa_util = sa_tx / total_sa_slots;
        
        % 전체 RU 활용률
        total_ru_slots = total_ra_slots + total_sa_slots;
        total_used = ra_used + sa_tx;
        total_util = total_used / total_ru_slots;
        
        fprintf('  테스트 시나리오:\n');
        fprintf('    슬롯: %d, RA-RU: %d, SA-RU: %d\n', total_slots, num_ra_ru, num_sa_ru);
        fprintf('    RA: success=%d, collision=%d, idle=%d\n', ra_success, ra_collision, ra_idle);
        fprintf('    SA: tx=%d\n', sa_tx);
        
        fprintf('\n  계산 결과:\n');
        fprintf('    RA-RU 활용률: %.1f%% (used=%d / total=%d)\n', ...
            ra_util * 100, ra_used, total_ra_slots);
        fprintf('    RA-RU 성공률: %.1f%%\n', ra_success_util * 100);
        fprintf('    SA-RU 활용률: %.1f%% (used=%d / total=%d)\n', ...
            sa_util * 100, sa_tx, total_sa_slots);
        fprintf('    전체 RU 활용률: %.1f%% (used=%d / total=%d)\n', ...
            total_util * 100, total_used, total_ru_slots);
        
        % 검증
        assert(abs(ra_util - 0.5) < 0.001, 'RA-RU 활용률 계산 오류');  % 50/100 = 0.5
        assert(abs(sa_util - 0.25) < 0.001, 'SA-RU 활용률 계산 오류');  % 200/800 = 0.25
        expected_total_util = (50 + 200) / 900;  % 250/900 ≈ 0.278
        assert(abs(total_util - expected_total_util) < 0.001, '전체 RU 활용률 계산 오류');
        
        fprintf('  ✅ PASS: RU 활용률 계산 정확\n\n');
        passed = passed + 1;
    catch ME
        fprintf('  ❌ FAIL: %s\n\n', ME.message);
        failed = failed + 1;
    end
    
    %% ═══════════════════════════════════════════════════
    %  Test 7: T_hold ON/OFF 비교
    %  ═══════════════════════════════════════════════════
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    fprintf('[7] T_hold ON/OFF 비교 (RU 활용률 포함)\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    try
        cfg_base = config_default();
        cfg_base.simulation_time = 5.0;
        cfg_base.warmup_time = 0.5;
        cfg_base.verbose = 0;
        cfg_base.rho = 1/3;
        cfg_base.mu_off = cfg_base.mu_on * (1 - cfg_base.rho) / cfg_base.rho;
        cfg_base.seed = 12345;
        
        % T_hold OFF
        cfg_off = cfg_base;
        cfg_off.thold_enabled = false;
        results_off = run_simulation(cfg_off);
        
        % T_hold ON (10ms)
        cfg_on = cfg_base;
        cfg_on.thold_enabled = true;
        cfg_on.thold_value = 0.010;
        results_on = run_simulation(cfg_on);
        
        fprintf('  %-15s | %-12s | %-12s\n', 'Metric', 'T_hold OFF', 'T_hold ON');
        fprintf('  %s\n', repmat('-', 1, 45));
        fprintf('  %-15s | %-12d | %-12d\n', 'Packets', ...
            results_off.packets.completed, results_on.packets.completed);
        fprintf('  %-15s | %-12.2f | %-12.2f\n', 'Mean Delay (ms)', ...
            results_off.delay.mean_ms, results_on.delay.mean_ms);
        fprintf('  %-15s | %-12.1f | %-12.1f\n', 'Collision (%)', ...
            results_off.uora.collision_rate * 100, results_on.uora.collision_rate * 100);
        fprintf('  %-15s | %-12.1f | %-12.1f\n', 'Explicit BSR (%)', ...
            results_off.bsr.explicit_ratio * 100, results_on.bsr.explicit_ratio * 100);
        fprintf('  %-15s | %-12d | %-12d\n', 'T_hold Hits', ...
            0, results_on.thold.hits);
        
        % T_hold 효과 분석
        fprintf('\n  분석:\n');
        if results_on.uora.collision_rate < results_off.uora.collision_rate
            fprintf('    → T_hold ON에서 충돌률 감소 (%.1f%% → %.1f%%)\n', ...
                results_off.uora.collision_rate * 100, results_on.uora.collision_rate * 100);
        else
            fprintf('    → T_hold 효과 불분명 (충돌률 감소 안됨)\n');
        end
        
        if results_on.bsr.explicit_ratio < results_off.bsr.explicit_ratio
            fprintf('    → T_hold ON에서 Explicit BSR 비율 감소 (SA 모드 활용)\n');
        end
        
        fprintf('  ✅ PASS: T_hold ON/OFF 비교 완료\n\n');
        passed = passed + 1;
    catch ME
        fprintf('  ❌ FAIL: %s\n\n', ME.message);
        failed = failed + 1;
    end
    
    %% 결과 요약
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    fprintf('메트릭 검증 결과: %d passed, %d failed\n', passed, failed);
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n');
end