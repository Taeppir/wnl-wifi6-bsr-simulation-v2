%% test_bugfix_comparison.m
% 버그 수정 확인: 지난 주간보고(251229)와 동일한 환경
%
% 환경:
%   - STA = 20
%   - rho = 0.5, mu_on = 50ms, mu_off = 50ms
%   - lambda = 50 pkt/s
%   - T_hold = [Base, 30, 50, 70] ms
%   - simulation_time = 30s
%   - seeds = 3

clear; clc;
fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════════╗\n');
fprintf('║      버그 수정 확인 - 지난 주간보고(251229) 환경 재현            ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════╝\n\n');

%% 실험 설정
seeds = [1234, 5678, 9012];
sim_time = 20;
thold_cases = [0, 30, 50, 70];  % 0 = Baseline
case_names = {'Base', 'T=30', 'T=50', 'T=70'};
num_seeds = length(seeds);

%% 결과 저장
results_all = struct();
throughput_mean = zeros(1, 4);
throughput_std = zeros(1, 4);
completion_mean = zeros(1, 4);
completion_std = zeros(1, 4);

%% 실험 실행
total_runs = length(thold_cases) * num_seeds;
run_count = 0;

for c = 1:length(thold_cases)
    th = thold_cases(c);
    
    tput_seeds = zeros(1, num_seeds);
    comp_seeds = zeros(1, num_seeds);
    
    for s = 1:num_seeds
        run_count = run_count + 1;
        fprintf('[%d/%d] %s, seed=%d ... ', run_count, total_runs, case_names{c}, s);
        
        % config_default() 사용
        cfg = config_default();
        
        % 지난 주간보고 환경
        cfg.simulation_time = sim_time;
        cfg.seed = seeds(s);
        cfg.verbose = 0;
        
        % 트래픽: rho=0.5, mu_on=50ms, mu_off=50ms, lambda=50
        cfg.traffic_model = 'pareto_onoff';
        cfg.mu_on = 0.050;    % 50ms
        cfg.rho = 0.5;
        cfg.mu_off = cfg.mu_on * (1 - cfg.rho) / cfg.rho;  % 50ms
        cfg.lambda = 50;
        cfg.pareto_alpha = 1.5;
        
        if th == 0
            % Baseline
            cfg.thold_enabled = false;
        else
            % T_hold 활성화
            cfg.thold_enabled = true;
            cfg.thold_value = th / 1000;  % ms -> 초
            cfg.thold_method = 'M0';
            cfg.thold_max_phantom = Inf;
        end
        
        tic;
        result = run_simulation(cfg);
        elapsed = toc;
        
        tput_seeds(s) = result.throughput.total_mbps;
        comp_seeds(s) = result.packets.completion_rate * 100;
        
        fprintf('%.1f Mbps, %.1f%% (%.1fs)\n', tput_seeds(s), comp_seeds(s), elapsed);
        
        % 결과 저장
        field_name = sprintf('case%d_s%d', c, s);
        results_all.(field_name) = result;
    end
    
    throughput_mean(c) = mean(tput_seeds);
    throughput_std(c) = std(tput_seeds);
    completion_mean(c) = mean(comp_seeds);
    completion_std(c) = std(comp_seeds);
end

%% 결과 출력
fprintf('\n');
fprintf('═══════════════════════════════════════════════════════════════════\n');
fprintf('                         결과 요약\n');
fprintf('═══════════════════════════════════════════════════════════════════\n\n');

fprintf('%-10s %15s %15s\n', 'Case', 'Throughput', 'Completion');
fprintf('%-10s %15s %15s\n', '', '(Mbps)', 'Rate (%)');
fprintf('─────────────────────────────────────────────────────────\n');
for c = 1:length(thold_cases)
    fprintf('%-10s %10.1f±%.1f %10.1f±%.1f\n', ...
        case_names{c}, throughput_mean(c), throughput_std(c), ...
        completion_mean(c), completion_std(c));
end
fprintf('═══════════════════════════════════════════════════════════════════\n');

%% 버그 확인
fprintf('\n[버그 수정 확인]\n');
if completion_mean(2) > 80  % T=30의 Completion Rate
    fprintf('  ✅ T=30ms Completion Rate %.1f%% → 버그 수정됨!\n', completion_mean(2));
else
    fprintf('  ❌ T=30ms Completion Rate %.1f%% → 버그 여전히 존재!\n', completion_mean(2));
end

%% Figure 생성
figure('Name', 'Bugfix Test Results', 'Position', [100 100 1000 400]);

% Throughput
subplot(1, 2, 1);
b1 = bar(throughput_mean);
hold on;
errorbar(1:4, throughput_mean, throughput_std, 'k', 'linestyle', 'none', 'LineWidth', 1.5);
hold off;

b1.FaceColor = 'flat';
b1.CData(1,:) = [0.2 0.4 0.8];  % Base: 파랑
b1.CData(2,:) = [0.8 0.2 0.2];  % T=30: 빨강
b1.CData(3,:) = [0.9 0.7 0.1];  % T=50: 노랑
b1.CData(4,:) = [0.2 0.7 0.3];  % T=70: 초록

set(gca, 'XTickLabel', case_names);
ylabel('Throughput (Mbps)');
title('Throughput Comparison (STA=20, \rho=0.5)');
grid on;

for i = 1:4
    text(i, throughput_mean(i) + throughput_std(i) + 0.3, ...
        sprintf('%.1f±%.1f', throughput_mean(i), throughput_std(i)), ...
        'HorizontalAlignment', 'center', 'FontSize', 9);
end

% Completion Rate
subplot(1, 2, 2);
b2 = bar(completion_mean);
hold on;
errorbar(1:4, completion_mean, completion_std, 'k', 'linestyle', 'none', 'LineWidth', 1.5);
hold off;

b2.FaceColor = 'flat';
b2.CData(1,:) = [0.2 0.4 0.8];
b2.CData(2,:) = [0.8 0.2 0.2];
b2.CData(3,:) = [0.9 0.7 0.1];
b2.CData(4,:) = [0.2 0.7 0.3];

set(gca, 'XTickLabel', case_names);
ylabel('Completion Rate (%)');
title('Completion Rate (STA=20, \rho=0.5)');
ylim([0 110]);
grid on;

for i = 1:4
    text(i, completion_mean(i) + completion_std(i) + 3, ...
        sprintf('%.1f±%.1f', completion_mean(i), completion_std(i)), ...
        'HorizontalAlignment', 'center', 'FontSize', 9);
end

sgtitle('버그 수정 확인 테스트 (M0, 지난 주간보고 환경)');

% 저장
output_dir = 'results';
if ~exist(output_dir, 'dir'), mkdir(output_dir); end
saveas(gcf, fullfile(output_dir, 'bugfix_test_result.png'));
fprintf('\n[Figure 저장] %s/bugfix_test_result.png\n', output_dir);

% 결과 저장
save(fullfile(output_dir, 'bugfix_test_results.mat'), 'results_all', ...
    'throughput_mean', 'throughput_std', 'completion_mean', 'completion_std', ...
    'thold_cases', 'case_names');
fprintf('[결과 저장] %s/bugfix_test_results.mat\n', output_dir);