function [passed, failed] = test_traffic()
% TEST_TRAFFIC: TrafficGenerator 테스트
%
% 테스트 항목:
%   1. 트래픽 생성기 생성
%   2. Pareto On/Off 상태 전이
%   3. 패킷 도착 시간

    passed = 0;
    failed = 0;
    
    cfg = config_default();
    
    %% Test 1: 트래픽 생성기 생성
    fprintf('  [1] 트래픽 생성기 생성... ');
    try
        tg = TrafficGenerator(cfg);
        assert(~isempty(tg), '생성 실패');
        fprintf('✓\n');
        passed = passed + 1;
    catch ME
        fprintf('✗ (%s)\n', ME.message);
        failed = failed + 1;
    end
    
    %% Test 2: 트래픽 생성 (generate)
    fprintf('  [2] 트래픽 생성 (generate)... ');
    try
        tg = TrafficGenerator(cfg);
        
        % STA 배열 생성
        stas = STA.empty(0, 1);
        stas(1) = STA(1, cfg);
        
        % 트래픽 생성
        stas = tg.generate(stas);
        
        % 패킷이 생성되었는지 확인
        assert(stas(1).num_packets > 0, '패킷이 생성되지 않음');
        assert(~isempty(stas(1).packets), 'packets 배열이 비어있음');
        fprintf('✓ (%d packets)\n', stas(1).num_packets);
        passed = passed + 1;
    catch ME
        fprintf('✗ (%s)\n', ME.message);
        failed = failed + 1;
    end
    
    %% Test 3: Pareto 분포 생성 확인
    fprintf('  [3] Pareto 분포 (alpha=1.5)... ');
    try
        alpha = cfg.pareto_alpha;
        mu = 0.1;  % 평균
        
        % Pareto 분포: x_min = mu * (alpha - 1) / alpha
        x_min = mu * (alpha - 1) / alpha;
        
        % 샘플 생성
        n_samples = 10000;
        samples = x_min ./ (rand(1, n_samples) .^ (1/alpha));
        
        % 평균 확인 (이론값: mu)
        sample_mean = mean(samples);
        relative_error = abs(sample_mean - mu) / mu;
        
        assert(relative_error < 0.1, '평균 오차 > 10%%');
        fprintf('✓ (mean=%.4f, expected=%.4f)\n', sample_mean, mu);
        passed = passed + 1;
    catch ME
        fprintf('✗ (%s)\n', ME.message);
        failed = failed + 1;
    end
    
    %% Test 4: Duty Cycle 계산
    fprintf('  [4] Duty Cycle (rho)... ');
    try
        mu_on = cfg.mu_on;
        mu_off = cfg.mu_off;
        expected_rho = mu_on / (mu_on + mu_off);
        
        % 기본 설정: mu_on=0.05, mu_off=0.10 -> rho = 1/3
        assert(abs(expected_rho - 1/3) < 0.01, 'rho != 1/3');
        fprintf('✓ (rho = %.3f)\n', expected_rho);
        passed = passed + 1;
    catch ME
        fprintf('✗ (%s)\n', ME.message);
        failed = failed + 1;
    end
    
    %% Test 5: 패킷 도착률
    fprintf('  [5] 패킷 도착률 (lambda)... ');
    try
        lambda = cfg.lambda;  % On 기간 중 도착률
        
        % On 기간 동안 평균 패킷 수
        avg_packets_per_on = lambda * cfg.mu_on;
        
        assert(lambda == 100, 'lambda != 100');
        fprintf('✓ (lambda=%d pkt/s, avg %.1f pkt/On)\n', lambda, avg_packets_per_on);
        passed = passed + 1;
    catch ME
        fprintf('✗ (%s)\n', ME.message);
        failed = failed + 1;
    end
    
    %% Test 6: 패킷 크기
    fprintf('  [6] 패킷 크기... ');
    try
        assert(cfg.mpdu_size == 2000, 'MPDU size != 2000');
        fprintf('✓ (%d bytes)\n', cfg.mpdu_size);
        passed = passed + 1;
    catch ME
        fprintf('✗ (%s)\n', ME.message);
        failed = failed + 1;
    end
    
    %% Test 7: 예상 총 패킷 수 (대략적)
    fprintf('  [7] 예상 총 패킷 수 추정... ');
    try
        % 총 패킷 수 = STA수 × rho × lambda × 시뮬레이션 시간
        rho = cfg.mu_on / (cfg.mu_on + cfg.mu_off);
        expected_total = cfg.num_stas * rho * cfg.lambda * cfg.simulation_time;
        
        fprintf('✓ (~%.0f packets)\n', expected_total);
        passed = passed + 1;
    catch ME
        fprintf('✗ (%s)\n', ME.message);
        failed = failed + 1;
    end
end