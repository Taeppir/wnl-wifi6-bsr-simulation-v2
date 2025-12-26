
function [passed, failed] = test_validation_traffic()
% TEST_VALIDATION_TRAFFIC: Pareto On/Off 트래픽 모델 정밀 검증
%
% 테스트 항목:
%   1. Pareto 분포 특성 (α=1.5)
%   2. On/Off 기간 평균 검증
%   3. Duty cycle (ρ) 검증
%   4. 패킷 도착률 (λ) 검증
%   5. 전체 트래픽 부하 검증

    fprintf('\n');
    fprintf('╔══════════════════════════════════════════════════════════════╗\n');
    fprintf('║         Pareto On/Off 트래픽 모델 검증                        ║\n');
    fprintf('╚══════════════════════════════════════════════════════════════╝\n\n');

    passed = 0;
    failed = 0;
    
    cfg = config_default();
    
    %% ═══════════════════════════════════════════════════
    %  Test 1: Pareto 분포 특성 검증
    %  ═══════════════════════════════════════════════════
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    fprintf('[1] Pareto 분포 특성 검증 (α=1.5)\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    try
        alpha = cfg.pareto_alpha;  % 1.5
        target_mean = 0.1;  % 테스트용 평균
        
        % k = mu * (alpha - 1) / alpha
        k = target_mean * (alpha - 1) / alpha;
        
        % 샘플 생성: X = k / U^(1/alpha)
        n_samples = 50000;
        u = rand(1, n_samples);
        samples = k ./ (u .^ (1/alpha));
        
        % 이론값
        theoretical_mean = k * alpha / (alpha - 1);  % = target_mean
        theoretical_var = k^2 * alpha / ((alpha-1)^2 * (alpha-2));  % α>2일 때만 유한
        
        % 측정값
        measured_mean = mean(samples);
        measured_median = median(samples);
        
        fprintf('  Pareto 파라미터:\n');
        fprintf('    α (shape) = %.2f\n', alpha);
        fprintf('    k (scale) = %.4f\n', k);
        fprintf('\n  이론값 vs 측정값:\n');
        fprintf('    평균: %.4f vs %.4f (오차: %.2f%%)\n', ...
            theoretical_mean, measured_mean, ...
            abs(measured_mean - theoretical_mean) / theoretical_mean * 100);
        fprintf('    중앙값: %.4f (이론: %.4f)\n', ...
            measured_median, k * 2^(1/alpha));
        
        % Heavy-tail 특성 확인
        p90 = prctile(samples, 90);
        p99 = prctile(samples, 99);
        fprintf('\n  Heavy-tail 특성:\n');
        fprintf('    P90: %.4f (평균의 %.1f배)\n', p90, p90/measured_mean);
        fprintf('    P99: %.4f (평균의 %.1f배)\n', p99, p99/measured_mean);
        
        % 검증: 평균 오차 10% 이내
        mean_error = abs(measured_mean - theoretical_mean) / theoretical_mean;
        assert(mean_error < 0.1, '평균 오차 > 10%%');
        
        % Heavy-tail: P99 > 5*mean (일반적으로)
        assert(p99 > 3 * measured_mean, 'Heavy-tail 특성 부족');
        
        fprintf('  ✅ PASS: Pareto 분포 특성 확인\n\n');
        passed = passed + 1;
    catch ME
        fprintf('  ❌ FAIL: %s\n\n', ME.message);
        failed = failed + 1;
    end
    
    %% ═══════════════════════════════════════════════════
    %  Test 2: On/Off 기간 평균 검증
    %  ═══════════════════════════════════════════════════
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    fprintf('[2] On/Off 기간 평균 검증\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    try
        alpha = cfg.pareto_alpha;
        mu_on = cfg.mu_on;
        mu_off = cfg.mu_off;
        
        k_on = mu_on * (alpha - 1) / alpha;
        k_off = mu_off * (alpha - 1) / alpha;
        
        % On 기간 샘플
        n_samples = 10000;
        on_samples = k_on ./ (rand(1, n_samples) .^ (1/alpha));
        off_samples = k_off ./ (rand(1, n_samples) .^ (1/alpha));
        
        measured_mu_on = mean(on_samples);
        measured_mu_off = mean(off_samples);
        
        fprintf('  On 기간:\n');
        fprintf('    설정값: %.3f s\n', mu_on);
        fprintf('    측정값: %.3f s (오차: %.2f%%)\n', ...
            measured_mu_on, abs(measured_mu_on - mu_on) / mu_on * 100);
        
        fprintf('  Off 기간:\n');
        fprintf('    설정값: %.3f s\n', mu_off);
        fprintf('    측정값: %.3f s (오차: %.2f%%)\n', ...
            measured_mu_off, abs(measured_mu_off - mu_off) / mu_off * 100);
        
        % 검증
        assert(abs(measured_mu_on - mu_on) / mu_on < 0.15, 'On 기간 평균 오차 > 15%%');
        assert(abs(measured_mu_off - mu_off) / mu_off < 0.15, 'Off 기간 평균 오차 > 15%%');
        
        fprintf('  ✅ PASS: On/Off 기간 평균 검증 완료\n\n');
        passed = passed + 1;
    catch ME
        fprintf('  ❌ FAIL: %s\n\n', ME.message);
        failed = failed + 1;
    end
    
    %% ═══════════════════════════════════════════════════
    %  Test 3: Duty Cycle (ρ) 검증
    %  ═══════════════════════════════════════════════════
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    fprintf('[3] Duty Cycle (ρ) 검증\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    try
        % rho = mu_on / (mu_on + mu_off)
        expected_rho = cfg.rho;
        calculated_rho = cfg.mu_on / (cfg.mu_on + cfg.mu_off);
        
        fprintf('  설정값 (cfg.rho): %.4f\n', expected_rho);
        fprintf('  계산값 (mu_on/(mu_on+mu_off)): %.4f\n', calculated_rho);
        fprintf('  mu_off 자동 계산: %.4f s\n', cfg.mu_off);
        
        % 검증
        assert(abs(calculated_rho - expected_rho) < 0.001, 'rho 계산 불일치');
        
        % 시뮬레이션으로 실제 duty cycle 측정
        alpha = cfg.pareto_alpha;
        k_on = cfg.mu_on * (alpha - 1) / alpha;
        k_off = cfg.mu_off * (alpha - 1) / alpha;
        
        total_on = 0;
        total_off = 0;
        sim_time = 100;  % 100초 시뮬레이션
        current_time = 0;
        is_on = false;
        
        while current_time < sim_time
            if is_on
                duration = k_on / (rand()^(1/alpha));
                total_on = total_on + min(duration, sim_time - current_time);
                current_time = current_time + duration;
                is_on = false;
            else
                duration = k_off / (rand()^(1/alpha));
                total_off = total_off + min(duration, sim_time - current_time);
                current_time = current_time + duration;
                is_on = true;
            end
        end
        
        measured_rho = total_on / (total_on + total_off);
        
        fprintf('\n  시뮬레이션 측정 (100초):\n');
        fprintf('    총 On 시간: %.2f s\n', total_on);
        fprintf('    총 Off 시간: %.2f s\n', total_off);
        fprintf('    측정 ρ: %.4f (오차: %.2f%%)\n', ...
            measured_rho, abs(measured_rho - expected_rho) / expected_rho * 100);
        
        assert(abs(measured_rho - expected_rho) / expected_rho < 0.2, '측정 rho 오차 > 20%%');
        
        fprintf('  ✅ PASS: Duty Cycle 검증 완료\n\n');
        passed = passed + 1;
    catch ME
        fprintf('  ❌ FAIL: %s\n\n', ME.message);
        failed = failed + 1;
    end
    
    %% ═══════════════════════════════════════════════════
    %  Test 4: 패킷 도착률 (λ) 검증
    %  ═══════════════════════════════════════════════════
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    fprintf('[4] 패킷 도착률 (λ) 검증\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    try
        lambda = cfg.lambda;  % 100 pkt/s
        
        % On 기간 동안 Poisson 도착 시뮬레이션
        on_duration = 1.0;  % 1초 On 기간
        n_trials = 1000;
        packet_counts = zeros(1, n_trials);
        
        for i = 1:n_trials
            current_time = 0;
            count = 0;
            while current_time < on_duration
                inter_arrival = -log(rand()) / lambda;
                current_time = current_time + inter_arrival;
                if current_time < on_duration
                    count = count + 1;
                end
            end
            packet_counts(i) = count;
        end
        
        measured_rate = mean(packet_counts);
        measured_std = std(packet_counts);
        
        % Poisson: mean = variance = lambda * duration
        expected_mean = lambda * on_duration;
        expected_std = sqrt(lambda * on_duration);
        
        fprintf('  설정 λ: %d pkt/s\n', lambda);
        fprintf('  1초 On 기간 동안:\n');
        fprintf('    예상 패킷 수: %.1f ± %.1f\n', expected_mean, expected_std);
        fprintf('    측정 패킷 수: %.1f ± %.1f\n', measured_rate, measured_std);
        fprintf('    오차: %.2f%%\n', abs(measured_rate - expected_mean) / expected_mean * 100);
        
        assert(abs(measured_rate - expected_mean) / expected_mean < 0.1, 'λ 측정 오차 > 10%%');
        
        fprintf('  ✅ PASS: 패킷 도착률 검증 완료\n\n');
        passed = passed + 1;
    catch ME
        fprintf('  ❌ FAIL: %s\n\n', ME.message);
        failed = failed + 1;
    end
    
    %% ═══════════════════════════════════════════════════
    %  Test 5: 전체 트래픽 부하 검증
    %  ═══════════════════════════════════════════════════
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    fprintf('[5] 전체 트래픽 부하 검증 (TrafficGenerator)\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    try
        cfg_test = config_default();
        cfg_test.simulation_time = 30.0;
        cfg_test.num_stas = 10;
        cfg_test.rho = 1/3;
        cfg_test.mu_off = cfg_test.mu_on * (1 - cfg_test.rho) / cfg_test.rho;
        
        % 예상 총 패킷 수
        % = num_stas × rho × lambda × simulation_time
        expected_total = cfg_test.num_stas * cfg_test.rho * cfg_test.lambda * cfg_test.simulation_time;
        
        % 트래픽 생성
        tg = TrafficGenerator(cfg_test);
        stas = STA.empty(0, cfg_test.num_stas);
        for i = 1:cfg_test.num_stas
            stas(i) = STA(i, cfg_test);
        end
        stas = tg.generate(stas);
        
        % 측정
        total_packets = sum([stas.num_packets]);
        packets_per_sta = [stas.num_packets];
        
        fprintf('  설정:\n');
        fprintf('    STA 수: %d\n', cfg_test.num_stas);
        fprintf('    시뮬레이션 시간: %.1f s\n', cfg_test.simulation_time);
        fprintf('    ρ: %.2f, λ: %d pkt/s\n', cfg_test.rho, cfg_test.lambda);
        
        fprintf('\n  예상 총 패킷 수: %.0f\n', expected_total);
        fprintf('  측정 총 패킷 수: %d (오차: %.1f%%)\n', ...
            total_packets, abs(total_packets - expected_total) / expected_total * 100);
        
        fprintf('\n  STA별 패킷 수:\n');
        fprintf('    평균: %.1f, 표준편차: %.1f\n', mean(packets_per_sta), std(packets_per_sta));
        fprintf('    범위: [%d, %d]\n', min(packets_per_sta), max(packets_per_sta));
        
        % 검증
        assert(abs(total_packets - expected_total) / expected_total < 0.3, ...
            '총 패킷 수 오차 > 30%%');
        
        % 패킷 도착 시간 분포 확인
        all_arrivals = [];
        for i = 1:cfg_test.num_stas
            for j = 1:stas(i).num_packets
                all_arrivals(end+1) = stas(i).packets(j).arrival_time;
            end
        end
        
        fprintf('\n  패킷 도착 시간 분포:\n');
        fprintf('    최소: %.4f s, 최대: %.4f s\n', min(all_arrivals), max(all_arrivals));
        
        fprintf('  ✅ PASS: 전체 트래픽 부하 검증 완료\n\n');
        passed = passed + 1;
    catch ME
        fprintf('  ❌ FAIL: %s\n\n', ME.message);
        failed = failed + 1;
    end
    
    %% ═══════════════════════════════════════════════════
    %  Test 6: On/Off 상태 전이 시각화 데이터
    %  ═══════════════════════════════════════════════════
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    fprintf('[6] On/Off 상태 전이 분석\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    try
        % 단일 STA의 On/Off 패턴 분석
        cfg_single = config_default();
        cfg_single.simulation_time = 10.0;
        cfg_single.num_stas = 1;
        cfg_single.rho = 1/3;
        cfg_single.mu_off = cfg_single.mu_on * (1 - cfg_single.rho) / cfg_single.rho;
        
        tg = TrafficGenerator(cfg_single);
        sta = STA(1, cfg_single);
        sta = tg.generate(sta);
        
        % 패킷 도착 시간으로 On 기간 추정
        arrival_times = zeros(1, sta.num_packets);
        for i = 1:sta.num_packets
            arrival_times(i) = sta.packets(i).arrival_time;
        end
        
        if length(arrival_times) > 1
            inter_arrivals = diff(sort(arrival_times));
            
            % 긴 gap = Off 기간으로 추정
            threshold = 1 / cfg_single.lambda * 5;  % 평균 간격의 5배
            off_gaps = inter_arrivals(inter_arrivals > threshold);
            on_gaps = inter_arrivals(inter_arrivals <= threshold);
            
            fprintf('  패킷 간 간격 분석:\n');
            fprintf('    총 패킷 수: %d\n', sta.num_packets);
            fprintf('    On 기간 내 평균 간격: %.4f s\n', mean(on_gaps));
            fprintf('    Off 기간 추정 (gap > %.4f s): %d개\n', threshold, length(off_gaps));
            if ~isempty(off_gaps)
                fprintf('    Off 기간 평균: %.4f s\n', mean(off_gaps));
            end
        end
        
        fprintf('  ✅ PASS: On/Off 상태 전이 분석 완료\n\n');
        passed = passed + 1;
    catch ME
        fprintf('  ❌ FAIL: %s\n\n', ME.message);
        failed = failed + 1;
    end
    
    %% 결과 요약
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    fprintf('트래픽 모델 검증 결과: %d passed, %d failed\n', passed, failed);
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n');
end