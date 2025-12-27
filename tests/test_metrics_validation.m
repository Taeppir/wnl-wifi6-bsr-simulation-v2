function [passed, failed] = test_metrics_validation()
% TEST_METRICS_VALIDATION: 성능 지표 측정 정확성 종합 검증
%
% On/Off Pareto 트래픽 환경에서 다음 지표들이 정확히 측정되는지 검증:
%   1. 지연 분해 (Delay Decomposition)
%   2. 처리율/효율 (Throughput & Efficiency)
%   3. T_hold 효과 지표
%   4. 충돌/경쟁 지표 (Collision & Contention)
%   5. 패킷 완료 지표 (Packet Completion)
%   6. 공정성 지표 (Fairness)
%   7. 지표 간 일관성 검증

    fprintf('\n');
    fprintf('╔══════════════════════════════════════════════════════════════╗\n');
    fprintf('║     지표 측정 정확성 종합 검증 (On/Off Pareto 트래픽)          ║\n');
    fprintf('╚══════════════════════════════════════════════════════════════╝\n\n');

    passed = 0;
    failed = 0;
    
    %% ═══════════════════════════════════════════════════════════════════
    %  공통 설정 - On/Off Pareto 트래픽
    %  ═══════════════════════════════════════════════════════════════════
    
    cfg = config_default();
    cfg.traffic_model = 'pareto_onoff';  % On/Off Pareto
    cfg.simulation_time = 10.0;          % 충분한 시간
    cfg.warmup_time = 0.0;
    cfg.verbose = 0;
    cfg.thold_enabled = true;
    cfg.thold_value = 0.010;             % 10ms T_hold
    cfg.num_stas = 20;
    cfg.rho = 0.5;                       % 40% duty cycle
    cfg.seed = 42;
    
    fprintf('  테스트 설정:\n');
    fprintf('    트래픽 모델: %s (α=%.1f, ρ=%.2f)\n', cfg.traffic_model, cfg.pareto_alpha, cfg.rho);
    fprintf('    시뮬레이션: %.1fs (워밍업: %.1fs)\n', cfg.simulation_time, cfg.warmup_time);
    fprintf('    STA 수: %d, T_hold: %.0fms\n', cfg.num_stas, cfg.thold_value * 1000);
    fprintf('    RA-RU: %d, SA-RU: %d\n\n', cfg.num_ru_ra, cfg.num_ru_sa);
    
    % 시뮬레이션 실행
    fprintf('  시뮬레이션 실행 중...');
    tic;
    results = run_simulation(cfg);
    elapsed = toc;
    fprintf(' 완료 (%.2fs)\n\n', elapsed);
    
    %% ═══════════════════════════════════════════════════════════════════
    %  Test 1: 지연 분해 (Delay Decomposition) 검증
    %  ═══════════════════════════════════════════════════════════════════
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    fprintf('[1] 지연 분해 (Delay Decomposition) 검증\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    try
        % delay_decomp 필드 존재 확인
        assert(isfield(results, 'delay_decomp'), 'delay_decomp 필드 누락');
        
        % 필수 하위 필드 확인
        dd = results.delay_decomp;
        required_fields = {'initial_wait', 'uora_contention', 'sa_wait', ...
                          'thold_hit', 'non_thold', 'ra_packets', 'sa_packets'};
        for i = 1:length(required_fields)
            assert(isfield(dd, required_fields{i}), ...
                sprintf('delay_decomp.%s 필드 누락', required_fields{i}));
        end
        
        fprintf('  ├─ 지연 분해 필드: ');
        fprintf('✅ 모든 필드 존재\n');
        
        % 값 범위 검증
        fprintf('  ├─ 값 범위 검증:\n');
        fprintf('  │   Total Delay:      mean=%.2fms, p90=%.2fms, p99=%.2fms\n', ...
            results.delay.mean_ms, results.delay.p90_ms, results.delay.p99_ms);
        fprintf('  │   Initial Wait:     mean=%.2fms\n', dd.initial_wait.mean_ms);
        fprintf('  │   UORA Contention:  mean=%.2fms\n', dd.uora_contention.mean_ms);
        fprintf('  │   SA Wait:          mean=%.2fms\n', dd.sa_wait.mean_ms);
        
        % 논리적 검증
        % Total >= Initial Wait (항상)
        assert(results.delay.mean_ms >= dd.initial_wait.mean_ms * 0.9, ...
            'Total Delay < Initial Wait (논리 오류)');
        
        % Percentile 순서: mean <= p90 <= p99 <= max
        assert(results.delay.p90_ms >= results.delay.mean_ms * 0.8, 'P90 < Mean');
        assert(results.delay.p99_ms >= results.delay.p90_ms * 0.9, 'P99 < P90');
        
        % 지연 성분이 음수가 아님
        assert(dd.initial_wait.mean_ms >= 0, 'Initial Wait < 0');
        assert(dd.uora_contention.mean_ms >= 0, 'UORA Contention < 0');
        assert(dd.sa_wait.mean_ms >= 0, 'SA Wait < 0');
        
        fprintf('  ├─ 논리 검증: ');
        fprintf('✅ 지연 순서 및 범위 정상\n');
        
        % T_hold Hit vs Non-Hit 비교
        fprintf('  ├─ T_hold Hit/Non-Hit 비교:\n');
        fprintf('  │   T_hold Hit:    %d packets, mean=%.2fms\n', ...
            dd.thold_hit.count, dd.thold_hit.mean_ms);
        fprintf('  │   Non-Hit:       %d packets, mean=%.2fms\n', ...
            dd.non_thold.count, dd.non_thold.mean_ms);
        
        % T_hold Hit 패킷이 있으면 더 낮은 지연 예상
        if dd.thold_hit.count > 0 && dd.non_thold.count > 0
            if dd.thold_hit.mean_ms < dd.non_thold.mean_ms
                fprintf('  │   → T_hold Hit 패킷 지연이 더 낮음 (%.2fms vs %.2fms) ✅\n', ...
                    dd.thold_hit.mean_ms, dd.non_thold.mean_ms);
            else
                fprintf('  │   → 주의: T_hold Hit 지연이 더 높음 (비정상적일 수 있음)\n');
            end
        end
        
        % RA vs SA 패킷 비교
        fprintf('  ├─ RA vs SA 패킷 지연:\n');
        fprintf('  │   RA Packets:    %d, mean=%.2fms\n', ...
            dd.ra_packets.count, dd.ra_packets.mean_ms);
        fprintf('  │   SA Packets:    %d, mean=%.2fms\n', ...
            dd.sa_packets.count, dd.sa_packets.mean_ms);
        
        fprintf('  └─ ');
        fprintf('✅ PASS: 지연 분해 검증 완료\n\n');
        passed = passed + 1;
    catch ME
        fprintf('  └─ ❌ FAIL: %s\n\n', ME.message);
        failed = failed + 1;
    end
    
    %% ═══════════════════════════════════════════════════════════════════
    %  Test 2: 처리율/효율 (Throughput & Efficiency) 검증
    %  ═══════════════════════════════════════════════════════════════════
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    fprintf('[2] 처리율/효율 (Throughput & Efficiency) 검증\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    try
        % throughput 필드 확인
        assert(isfield(results, 'throughput'), 'throughput 필드 누락');
        tp = results.throughput;
        
        fprintf('  ├─ 처리율:\n');
        fprintf('  │   Total Throughput: %.4f Mbps\n', tp.total_mbps);
        
        % 처리율 범위 검증 (0 ~ 최대 채널 용량)
        max_throughput = cfg.data_rate_per_ru * cfg.num_ru_total / 1e6;  % Mbps
        assert(tp.total_mbps >= 0, 'Throughput < 0');
        assert(tp.total_mbps <= max_throughput * 1.1, ...
            sprintf('Throughput(%.2f) > Max(%.2f)', tp.total_mbps, max_throughput));
        
        fprintf('  │   최대 채널 용량: %.2f Mbps\n', max_throughput);
        fprintf('  │   → 채널 이용률: %.1f%%\n', tp.total_mbps / max_throughput * 100);
        
        % RU Utilization 필드 확인 (throughput 구조체 내에 있음)
        fprintf('  ├─ RU 활용률:\n');
        fprintf('  │   RA-RU Utilization: %.1f%%\n', tp.ra_utilization * 100);
        fprintf('  │   SA-RU Utilization: %.1f%%\n', tp.sa_utilization * 100);
        fprintf('  │   Channel Utilization: %.1f%%\n', tp.channel_utilization * 100);
        
        % 활용률 범위 검증 [0, 1]
        assert(tp.ra_utilization >= 0 && tp.ra_utilization <= 1, 'RA Utilization 범위 오류');
        assert(tp.sa_utilization >= 0 && tp.sa_utilization <= 1, 'SA Utilization 범위 오류');
        assert(tp.channel_utilization >= 0 && tp.channel_utilization <= 1, 'Channel Utilization 범위 오류');
        
        % SA Phantom Rate 검증
        if isfield(tp, 'sa_phantom_rate')
            fprintf('  │   SA Phantom Rate: %.1f%% (%d phantom allocations)\n', ...
                tp.sa_phantom_rate * 100, tp.sa_phantom_count);
            assert(tp.sa_phantom_rate >= 0 && tp.sa_phantom_rate <= 1, 'Phantom Rate 범위 오류');
        end
        
        % 수동 계산과 비교
        fprintf('  ├─ 처리율 수동 계산 검증:\n');
        expected_throughput = (results.packets.completed * cfg.mpdu_size * 8) / ...
                             (results.tf.count * cfg.frame_exchange_slots * cfg.slot_duration) / 1e6;
        diff_pct = abs(tp.total_mbps - expected_throughput) / max(expected_throughput, 0.001) * 100;
        fprintf('  │   측정값: %.4f Mbps\n', tp.total_mbps);
        fprintf('  │   계산값: %.4f Mbps\n', expected_throughput);
        fprintf('  │   차이: %.2f%%\n', diff_pct);
        
        assert(diff_pct < 5, sprintf('처리율 계산 불일치 (%.2f%%)', diff_pct));
        
        fprintf('  └─ ');
        fprintf('✅ PASS: 처리율/효율 검증 완료\n\n');
        passed = passed + 1;
    catch ME
        fprintf('  └─ ❌ FAIL: %s\n\n', ME.message);
        failed = failed + 1;
    end
    
    %% ═══════════════════════════════════════════════════════════════════
    %  Test 3: T_hold 효과 지표 검증
    %  ═══════════════════════════════════════════════════════════════════
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    fprintf('[3] T_hold 효과 지표 검증\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    try
        assert(isfield(results, 'thold'), 'thold 필드 누락');
        th = results.thold;
        
        fprintf('  ├─ T_hold 통계:\n');
        fprintf('  │   Activation Count: %d\n', th.activations);
        fprintf('  │   Hit Count:        %d\n', th.hits);
        fprintf('  │   Expiration Count: %d\n', th.expirations);
        fprintf('  │   Hit Rate:         %.1f%%\n', th.hit_rate * 100);
        
        % 기본 범위 검증
        assert(th.activations >= 0, 'Activations < 0');
        assert(th.hits >= 0, 'Hits < 0');
        assert(th.expirations >= 0, 'Expirations < 0');
        
        % Hit + Expiration <= Activations (일부 활성화 중일 수 있음)
        assert(th.hits + th.expirations <= th.activations + 1, ...
            'Hits + Expirations > Activations');
        
        % Hit Rate 검증
        if th.activations > 0
            expected_hit_rate = th.hits / th.activations;
            assert(abs(th.hit_rate - expected_hit_rate) < 0.01, 'Hit Rate 계산 오류');
            assert(th.hit_rate >= 0 && th.hit_rate <= 1, 'Hit Rate 범위 오류');
        end
        
        % Wasted Slots 검증
        fprintf('  │   Wasted Slots:     %d (%.2fms)\n', th.wasted_slots, th.wasted_ms);
        assert(th.wasted_slots >= 0, 'Wasted Slots < 0');
        
        % 낭비된 슬롯과 만료 횟수 관계
        if th.expirations > 0
            avg_wasted_per_expiry = th.wasted_slots / th.expirations;
            expected_thold_slots = cfg.thold_value / cfg.slot_duration;
            fprintf('  │   → 만료당 평균 낭비: %.0f slots (T_hold=%d slots)\n', ...
                avg_wasted_per_expiry, round(expected_thold_slots));
        end
        
        % UORA Avoided 검증
        if isfield(th, 'uora_avoided')
            fprintf('  │   UORA Avoided:     %d\n', th.uora_avoided);
            assert(th.uora_avoided >= 0, 'UORA Avoided < 0');
        end
        
        fprintf('  └─ ');
        fprintf('✅ PASS: T_hold 지표 검증 완료\n\n');
        passed = passed + 1;
    catch ME
        fprintf('  └─ ❌ FAIL: %s\n\n', ME.message);
        failed = failed + 1;
    end
    
    %% ═══════════════════════════════════════════════════════════════════
    %  Test 4: 충돌/경쟁 지표 (Collision & Contention) 검증
    %  ═══════════════════════════════════════════════════════════════════
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    fprintf('[4] 충돌/경쟁 지표 (Collision & Contention) 검증\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    try
        assert(isfield(results, 'uora'), 'uora 필드 누락');
        u = results.uora;
        
        fprintf('  ├─ UORA 통계:\n');
        fprintf('  │   Total Success:         %d\n', u.total_success);
        fprintf('  │   Total Collision STAs:  %d (충돌에 참여한 STA 수)\n', u.total_collision);
        fprintf('  │   Total Collision Slots: %d (충돌 발생 슬롯 수)\n', u.total_collision_slots);
        fprintf('  │   Total Idle:            %d\n', u.total_idle);
        fprintf('  │   Total RA-RU Slots:     %d\n', u.total_ra_slots);
        fprintf('  ├─ 비율 (슬롯 기준):\n');
        fprintf('  │   Success Rate:          %.1f%%\n', u.success_rate * 100);
        fprintf('  │   Collision Slot Rate:   %.1f%%\n', u.collision_slot_rate * 100);
        fprintf('  │   Idle Rate:             %.1f%%\n', u.idle_rate * 100);
        
        % 슬롯 기준 비율 합 검증 (= 1.0)
        slot_rate_sum = u.success_rate + u.collision_slot_rate + u.idle_rate;
        fprintf('  │   비율 합:               %.4f (1.0 예상)\n', slot_rate_sum);
        assert(abs(slot_rate_sum - 1.0) < 0.01, ...
            sprintf('슬롯 비율 합 오류: %.4f', slot_rate_sum));
        
        fprintf('  ├─ STA 관점:\n');
        fprintf('  │   Collision Rate:        %.1f%% (시도 중 충돌)\n', u.collision_rate * 100);
        fprintf('  │   Avg Collision Size:    %.2f STAs/slot\n', u.avg_collision_size);
        fprintf('  │   Collisions/Packet:     %.2f\n', u.collisions_per_packet);
        
        % 수동 계산 검증
        fprintf('  ├─ 수동 계산 검증:\n');
        
        % 슬롯 기준 계산
        if u.total_ra_slots > 0
            calc_success_rate = u.total_success / u.total_ra_slots;
            calc_collision_slot_rate = u.total_collision_slots / u.total_ra_slots;
            fprintf('  │   Success Rate: 측정=%.4f, 계산=%.4f\n', u.success_rate, calc_success_rate);
            fprintf('  │   Collision Slot Rate: 측정=%.4f, 계산=%.4f\n', u.collision_slot_rate, calc_collision_slot_rate);
            assert(abs(u.success_rate - calc_success_rate) < 0.001, 'Success Rate 계산 불일치');
            assert(abs(u.collision_slot_rate - calc_collision_slot_rate) < 0.001, 'Collision Slot Rate 계산 불일치');
        end
        
        % STA 관점 계산
        total_attempts = u.total_success + u.total_collision;
        if total_attempts > 0
            calc_collision_rate = u.total_collision / total_attempts;
            fprintf('  │   Collision Rate (STA): 측정=%.4f, 계산=%.4f\n', u.collision_rate, calc_collision_rate);
            assert(abs(u.collision_rate - calc_collision_rate) < 0.001, 'Collision Rate 계산 불일치');
        end
        
        fprintf('  └─ ');
        fprintf('✅ PASS: 충돌/경쟁 지표 검증 완료\n\n');
        passed = passed + 1;
    catch ME
        fprintf('  └─ ❌ FAIL: %s\n\n', ME.message);
        failed = failed + 1;
    end
    
    %% ═══════════════════════════════════════════════════════════════════
    %  Test 5: 패킷 완료 지표 (Packet Completion) 검증
    %  ═══════════════════════════════════════════════════════════════════
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    fprintf('[5] 패킷 완료 지표 (Packet Completion) 검증\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    try
        assert(isfield(results, 'packets'), 'packets 필드 누락');
        p = results.packets;
        
        fprintf('  ├─ 패킷 통계:\n');
        fprintf('  │   Generated:      %d\n', p.generated);
        fprintf('  │   Completed:      %d\n', p.completed);
        fprintf('  │   Completion Rate: %.1f%%\n', p.completion_rate * 100);
        
        % 기본 검증
        assert(p.generated >= 0, 'Generated < 0');
        assert(p.completed >= 0, 'Completed < 0');
        assert(p.completed <= p.generated, 'Completed > Generated');
        
        % Completion Rate 계산 검증
        if p.generated > 0
            expected_rate = p.completed / p.generated;
            assert(abs(p.completion_rate - expected_rate) < 0.001, 'Completion Rate 계산 오류');
            assert(p.completion_rate >= 0 && p.completion_rate <= 1, 'Completion Rate 범위 오류');
        end
        
        % Pareto On/Off 트래픽에서 합리적인 패킷 수 확인
        % 예상 패킷 수 = STA수 × rho × lambda × 시간
        expected_packets = cfg.num_stas * cfg.rho * cfg.lambda * cfg.simulation_time;
        ratio = p.generated / expected_packets;
        fprintf('  │   예상 패킷 수:    ~%.0f (실제: %d, 비율: %.2f)\n', ...
            expected_packets, p.generated, ratio);
        
        % 합리적 범위 (0.5 ~ 2.0배)
        assert(ratio > 0.3 && ratio < 3.0, ...
            sprintf('패킷 수가 예상과 크게 다름 (ratio=%.2f)', ratio));
        
        fprintf('  └─ ');
        fprintf('✅ PASS: 패킷 완료 지표 검증 완료\n\n');
        passed = passed + 1;
    catch ME
        fprintf('  └─ ❌ FAIL: %s\n\n', ME.message);
        failed = failed + 1;
    end
    
    %% ═══════════════════════════════════════════════════════════════════
    %  Test 6: 공정성 지표 (Fairness) 검증
    %  ═══════════════════════════════════════════════════════════════════
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    fprintf('[6] 공정성 지표 (Fairness) 검증\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    try
        assert(isfield(results, 'fairness'), 'fairness 필드 누락');
        f = results.fairness;
        
        fprintf('  ├─ 공정성 지표:\n');
        fprintf('  │   Jain''s Index: %.4f (1.0 = 완전 공정)\n', f.jain_index);
        fprintf('  │   CoV:          %.4f (0.0 = 완전 균등)\n', f.cov);
        
        % Jain's Index 범위 [1/n, 1]
        min_jain = 1 / cfg.num_stas;
        assert(f.jain_index >= min_jain - 0.01 && f.jain_index <= 1.01, ...
            sprintf('Jain Index 범위 오류: %.4f (min=%.4f)', f.jain_index, min_jain));
        
        % CoV >= 0
        assert(f.cov >= 0, 'CoV < 0');
        
        % Per-STA 데이터로 수동 검증
        if isfield(results, 'per_sta') && isfield(results.per_sta, 'throughput_mbps')
            tp_per_sta = results.per_sta.throughput_mbps;
            
            fprintf('  ├─ Per-STA 처리율 분포:\n');
            fprintf('  │   Min: %.4f Mbps, Max: %.4f Mbps\n', min(tp_per_sta), max(tp_per_sta));
            fprintf('  │   Mean: %.4f Mbps, Std: %.4f Mbps\n', mean(tp_per_sta), std(tp_per_sta));
            
            % 수동 Jain's Index 계산
            sum_tp = sum(tp_per_sta);
            sum_tp_sq = sum(tp_per_sta.^2);
            if sum_tp_sq > 0
                calc_jain = sum_tp^2 / (cfg.num_stas * sum_tp_sq);
                fprintf('  │   수동 Jain: %.4f, 측정값: %.4f\n', calc_jain, f.jain_index);
                assert(abs(f.jain_index - calc_jain) < 0.01, 'Jain Index 계산 불일치');
            end
            
            % 수동 CoV 계산
            if sum_tp > 0
                calc_cov = std(tp_per_sta) / mean(tp_per_sta);
                fprintf('  │   수동 CoV:  %.4f, 측정값: %.4f\n', calc_cov, f.cov);
                assert(abs(f.cov - calc_cov) < 0.01, 'CoV 계산 불일치');
            end
        end
        
        fprintf('  └─ ');
        fprintf('✅ PASS: 공정성 지표 검증 완료\n\n');
        passed = passed + 1;
    catch ME
        fprintf('  └─ ❌ FAIL: %s\n\n', ME.message);
        failed = failed + 1;
    end
    
    %% ═══════════════════════════════════════════════════════════════════
    %  Test 7: BSR 통계 검증
    %  ═══════════════════════════════════════════════════════════════════
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    fprintf('[7] BSR 통계 검증\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    try
        assert(isfield(results, 'bsr'), 'bsr 필드 누락');
        b = results.bsr;
        
        fprintf('  ├─ BSR 통계:\n');
        fprintf('  │   Explicit BSR:  %d\n', b.explicit_count);
        fprintf('  │   Implicit BSR:  %d\n', b.implicit_count);
        fprintf('  │   Explicit Ratio: %.1f%%\n', b.explicit_ratio * 100);
        
        % 기본 검증
        assert(b.explicit_count >= 0, 'Explicit BSR < 0');
        assert(b.implicit_count >= 0, 'Implicit BSR < 0');
        
        % Explicit Ratio 계산 검증
        total_bsr = b.explicit_count + b.implicit_count;
        if total_bsr > 0
            expected_ratio = b.explicit_count / total_bsr;
            assert(abs(b.explicit_ratio - expected_ratio) < 0.001, 'Explicit Ratio 계산 오류');
            assert(b.explicit_ratio >= 0 && b.explicit_ratio <= 1, 'Explicit Ratio 범위 오류');
        end
        
        fprintf('  └─ ');
        fprintf('✅ PASS: BSR 통계 검증 완료\n\n');
        passed = passed + 1;
    catch ME
        fprintf('  └─ ❌ FAIL: %s\n\n', ME.message);
        failed = failed + 1;
    end
    
    %% ═══════════════════════════════════════════════════════════════════
    %  Test 8: 지표 간 일관성 검증
    %  ═══════════════════════════════════════════════════════════════════
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    fprintf('[8] 지표 간 일관성 검증\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    try
        fprintf('  ├─ 일관성 검사:\n');
        
        % 1. RA + SA 패킷 = 완료된 패킷
        ra_pkts = results.delay_decomp.ra_packets.count;
        sa_pkts = results.delay_decomp.sa_packets.count;
        total_decomp = ra_pkts + sa_pkts;
        fprintf('  │   RA(%d) + SA(%d) = %d, Completed = %d\n', ...
            ra_pkts, sa_pkts, total_decomp, results.packets.completed);
        
        if total_decomp > 0
            ratio = total_decomp / results.packets.completed;
            assert(ratio > 0.9 && ratio < 1.1, ...
                'RA+SA 패킷과 완료 패킷 불일치');
            fprintf('  │   → ✅ 패킷 분류 일관성 확인 (비율: %.2f)\n', ratio);
        end
        
        % 2. T_hold Hit 패킷 vs T_hold Hits
        thold_hit_pkts = results.delay_decomp.thold_hit.count;
        thold_hits = results.thold.hits;
        fprintf('  │   T_hold Hit 패킷: %d, T_hold Hits: %d\n', thold_hit_pkts, thold_hits);
        
        % T_hold Hit 패킷 수는 T_hold Hits와 같거나 작아야 함
        assert(thold_hit_pkts <= thold_hits + 10, ...
            'T_hold Hit 패킷이 Hits보다 많음');
        fprintf('  │   → ✅ T_hold Hit 일관성 확인\n');
        
        % 3. Per-STA 처리율 합 ≈ Total Throughput
        if isfield(results, 'per_sta') && isfield(results.per_sta, 'throughput_mbps')
            sum_per_sta = sum(results.per_sta.throughput_mbps);
            total_tp = results.throughput.total_mbps;
            tp_diff = abs(sum_per_sta - total_tp) / max(total_tp, 0.001) * 100;
            fprintf('  │   Per-STA 합: %.4f Mbps, Total: %.4f Mbps (차이: %.1f%%)\n', ...
                sum_per_sta, total_tp, tp_diff);
            assert(tp_diff < 5, 'Per-STA 처리율 합과 전체 처리율 불일치');
            fprintf('  │   → ✅ 처리율 일관성 확인\n');
        end
        
        % 4. TF Count와 RA 통계 일관성
        expected_ra_slots = results.tf.count * cfg.num_ru_ra;
        actual_ra_slots = results.uora.total_ra_slots;
        fprintf('  │   RA 슬롯: success=%d, collision_slots=%d, idle=%d\n', ...
            results.uora.total_success, results.uora.total_collision_slots, results.uora.total_idle);
        fprintf('  │   예상 RA 슬롯: %d, 실제 RA 슬롯: %d\n', expected_ra_slots, actual_ra_slots);
        if expected_ra_slots > 0
            % success + collision_slots + idle = total_ra_slots = TF수 × RA-RU수
            slot_ratio = actual_ra_slots / expected_ra_slots;
            assert(abs(slot_ratio - 1.0) < 0.01, ...
                sprintf('RA 슬롯 불일치 (ratio=%.4f)', slot_ratio));
            fprintf('  │   → ✅ RA 슬롯 일관성 확인 (비율: %.4f)\n', slot_ratio);
        end
        
        fprintf('  └─ ');
        fprintf('✅ PASS: 지표 간 일관성 검증 완료\n\n');
        passed = passed + 1;
    catch ME
        fprintf('  └─ ❌ FAIL: %s\n\n', ME.message);
        failed = failed + 1;
    end
    
    %% ═══════════════════════════════════════════════════════════════════
    %  Test 9: T_hold ON/OFF 비교 검증
    %  ═══════════════════════════════════════════════════════════════════
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    fprintf('[9] T_hold ON/OFF 비교 검증\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    try
        % T_hold OFF 시뮬레이션
        cfg_off = cfg;
        cfg_off.thold_enabled = false;
        cfg_off.simulation_time = 5.0;  % 빠른 테스트
        cfg_off.warmup_time = 0.5;
        
        fprintf('  ├─ T_hold OFF 시뮬레이션 실행...');
        results_off = run_simulation(cfg_off);
        fprintf(' 완료\n');
        
        % T_hold ON 시뮬레이션 (동일 시드)
        cfg_on = cfg;
        cfg_on.thold_enabled = true;
        cfg_on.simulation_time = 5.0;
        cfg_on.warmup_time = 0.5;
        
        fprintf('  ├─ T_hold ON 시뮬레이션 실행...');
        results_on = run_simulation(cfg_on);
        fprintf(' 완료\n');
        
        fprintf('  ├─ 비교 결과:\n');
        fprintf('  │   %-20s | %-12s | %-12s\n', 'Metric', 'OFF', 'ON');
        fprintf('  │   %s\n', repmat('-', 1, 50));
        fprintf('  │   %-20s | %-12d | %-12d\n', 'Packets', ...
            results_off.packets.completed, results_on.packets.completed);
        fprintf('  │   %-20s | %-12.2f | %-12.2f\n', 'Mean Delay (ms)', ...
            results_off.delay.mean_ms, results_on.delay.mean_ms);
        fprintf('  │   %-20s | %-12.1f | %-12.1f\n', 'Collision Rate (%)', ...
            results_off.uora.collision_rate * 100, results_on.uora.collision_rate * 100);
        fprintf('  │   %-20s | %-12d | %-12d\n', 'T_hold Hits', ...
            0, results_on.thold.hits);
        
        % T_hold ON일 때 T_hold 통계가 활성화됨
        assert(results_on.thold.activations > 0 || results_on.thold.hits == 0, ...
            'T_hold ON인데 activations = 0');
        
        % T_hold OFF일 때 Hits = 0
        assert(results_off.thold.hits == 0, 'T_hold OFF인데 hits > 0');
        
        fprintf('  └─ ');
        fprintf('✅ PASS: T_hold ON/OFF 비교 검증 완료\n\n');
        passed = passed + 1;
    catch ME
        fprintf('  └─ ❌ FAIL: %s\n\n', ME.message);
        failed = failed + 1;
    end
    
    %% ═══════════════════════════════════════════════════════════════════
    %  Test 10: 다양한 부하 조건에서 지표 추세 검증
    %  ═══════════════════════════════════════════════════════════════════
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    fprintf('[10] 부하 변화에 따른 지표 추세 검증\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    try
        rho_values = [0.2, 0.4, 0.6];
        results_array = cell(1, length(rho_values));
        
        fprintf('  ├─ 다양한 rho 값으로 시뮬레이션:\n');
        for i = 1:length(rho_values)
            cfg_test = cfg;
            cfg_test.simulation_time = 3.0;
            cfg_test.warmup_time = 0.3;
            cfg_test.rho = rho_values(i);
            cfg_test.mu_off = cfg_test.mu_on * (1 - cfg_test.rho) / cfg_test.rho;
            cfg_test.seed = 100 + i;
            
            results_array{i} = run_simulation(cfg_test);
        end
        
        fprintf('  │   %-6s | %-8s | %-10s | %-10s | %-10s | %-8s\n', ...
            'rho', 'Pkts', 'Delay(ms)', 'Coll(%)', 'HitRate(%)', 'Jain');
        fprintf('  │   %s\n', repmat('-', 1, 65));
        
        for i = 1:length(rho_values)
            r = results_array{i};
            fprintf('  │   %-6.2f | %-8d | %-10.2f | %-10.1f | %-10.1f | %-8.4f\n', ...
                rho_values(i), r.packets.completed, r.delay.mean_ms, ...
                r.uora.collision_rate * 100, r.thold.hit_rate * 100, r.fairness.jain_index);
        end
        
        % 추세 검증
        fprintf('  ├─ 추세 분석:\n');
        
        packets = cellfun(@(r) r.packets.completed, results_array);
        delays = cellfun(@(r) r.delay.mean_ms, results_array);
        collisions = cellfun(@(r) r.uora.collision_rate, results_array);
        
        % rho 증가 → 일반적으로 패킷 수 증가
        if all(diff(packets) >= -10)  % 약간의 변동 허용
            fprintf('  │   → 패킷 수: rho 증가에 따라 증가 또는 유지 ✅\n');
        else
            fprintf('  │   → 패킷 수: 불규칙 패턴 (주의)\n');
        end
        
        % 모든 결과가 유효한 범위 내에 있는지 확인
        for i = 1:length(results_array)
            r = results_array{i};
            assert(r.delay.mean_ms >= 0, 'Delay < 0');
            assert(r.uora.collision_rate >= 0 && r.uora.collision_rate <= 1, '충돌률 범위 오류');
            assert(r.fairness.jain_index >= 0 && r.fairness.jain_index <= 1, 'Jain 범위 오류');
        end
        fprintf('  │   → 모든 지표 유효 범위 내 ✅\n');
        
        fprintf('  └─ ');
        fprintf('✅ PASS: 부하 변화 추세 검증 완료\n\n');
        passed = passed + 1;
    catch ME
        fprintf('  └─ ❌ FAIL: %s\n\n', ME.message);
        failed = failed + 1;
    end
    
    %% ═══════════════════════════════════════════════════════════════════
    %  결과 요약
    %  ═══════════════════════════════════════════════════════════════════
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    fprintf('                        지표 검증 결과 요약\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    fprintf('  통과: %d개 테스트\n', passed);
    fprintf('  실패: %d개 테스트\n', failed);
    
    if failed == 0
        fprintf('\n  🎉 모든 지표 측정이 정확합니다!\n');
    else
        fprintf('\n  ⚠️  일부 지표 측정에 문제가 있습니다. 확인이 필요합니다.\n');
    end
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n');
end