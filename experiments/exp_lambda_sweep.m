%% exp_lambda_sweep.m
% λ_on Sweep: Baseline vs T_hold (10ms) 비교 실험
%
% 이전 시뮬레이션과 동일한 설정:
%   - simulation_time = 10s
%   - num_runs = 10
%   - numSTAs = 20
%   - rho = 0.5
%   - mu_on = 0.01 (10ms)
%   - RA_RU = 1
%   - λ_on = [20, 50, 100] pkt/s

clear; clc;
addpath(genpath(pwd));

%% 실험 설정
lambda_values = [20, 50, 100];  % pkt/s
num_runs = 1;

% 고정 파라미터
sim_time = 10.0;
num_stas = 20;
rho = 0.5;
mu_on = 0.01;  % 10ms
mu_off = mu_on * (1 - rho) / rho;  % rho = 0.5 → mu_off = 0.01
thold_value = 0.010;  % 10ms

fprintf('╔══════════════════════════════════════════════════════════════╗\n');
fprintf('║     λ_on Sweep: Baseline vs T_hold (10ms)                    ║\n');
fprintf('╚══════════════════════════════════════════════════════════════╝\n\n');

fprintf('설정:\n');
fprintf('  simulation_time = %.1f s\n', sim_time);
fprintf('  num_runs = %d\n', num_runs);
fprintf('  numSTAs = %d\n', num_stas);
fprintf('  rho = %.2f\n', rho);
fprintf('  mu_on = %.3f s (%.1f ms)\n', mu_on, mu_on * 1000);
fprintf('  mu_off = %.3f s (%.1f ms)\n', mu_off, mu_off * 1000);
fprintf('  T_hold = %.3f s (%.1f ms)\n', thold_value, thold_value * 1000);
fprintf('  RA-RU = 1\n');
fprintf('  λ_on = %s pkt/s\n\n', mat2str(lambda_values));

%% 결과 저장 구조체
num_lambda = length(lambda_values);

results_baseline = struct();
results_thold = struct();

% 각 지표별 배열 초기화 (평균, 표준편차)
metrics = {'delay_mean', 'collision_rate', 'explicit_bsr_ratio', ...
           'throughput', 'completion_rate', 'packets_completed', ...
           'explicit_bsr_count', 'implicit_bsr_count'};

for m = 1:length(metrics)
    results_baseline.(metrics{m}).mean = zeros(1, num_lambda);
    results_baseline.(metrics{m}).std = zeros(1, num_lambda);
    results_thold.(metrics{m}).mean = zeros(1, num_lambda);
    results_thold.(metrics{m}).std = zeros(1, num_lambda);
end

%% 실험 실행
for li = 1:num_lambda
    lambda = lambda_values(li);
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    fprintf('λ_on = %d pkt/s 실험 중...\n', lambda);
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    % Run별 결과 저장
    run_baseline = zeros(num_runs, length(metrics));
    run_thold = zeros(num_runs, length(metrics));
    
    for run = 1:num_runs
        seed = 1000 * li + run;  % 재현 가능한 시드
        
        %% Baseline (T_hold OFF)
        cfg = config_default();
        cfg.simulation_time = sim_time;
        cfg.warmup_time = 1.0;
        cfg.num_stas = num_stas;
        cfg.rho = rho;
        cfg.mu_on = mu_on;
        cfg.mu_off = mu_off;
        cfg.lambda = lambda;
        cfg.thold_enabled = false;
        cfg.verbose = 0;
        cfg.seed = seed;
        
        r_base = run_simulation(cfg);
        
        run_baseline(run, 1) = r_base.delay.mean_ms;
        run_baseline(run, 2) = r_base.uora.collision_rate * 100;
        run_baseline(run, 3) = r_base.bsr.explicit_ratio * 100;
        run_baseline(run, 4) = r_base.throughput.total_mbps;
        run_baseline(run, 5) = r_base.packets.completion_rate * 100;
        run_baseline(run, 6) = r_base.packets.completed;
        run_baseline(run, 7) = r_base.bsr.explicit_count;
        run_baseline(run, 8) = r_base.bsr.implicit_count;
        
        %% T_hold ON (10ms)
        cfg.thold_enabled = true;
        cfg.thold_value = thold_value;
        cfg.seed = seed;  % 동일 시드
        
        r_thold = run_simulation(cfg);
        
        run_thold(run, 1) = r_thold.delay.mean_ms;
        run_thold(run, 2) = r_thold.uora.collision_rate * 100;
        run_thold(run, 3) = r_thold.bsr.explicit_ratio * 100;
        run_thold(run, 4) = r_thold.throughput.total_mbps;
        run_thold(run, 5) = r_thold.packets.completion_rate * 100;
        run_thold(run, 6) = r_thold.packets.completed;
        run_thold(run, 7) = r_thold.bsr.explicit_count;
        run_thold(run, 8) = r_thold.bsr.implicit_count;
        
        fprintf('  Run %2d: Base delay=%.1fms, T_hold delay=%.1fms\n', ...
            run, r_base.delay.mean_ms, r_thold.delay.mean_ms);
    end
    
    % 평균 및 표준편차 계산
    for m = 1:length(metrics)
        results_baseline.(metrics{m}).mean(li) = mean(run_baseline(:, m));
        results_baseline.(metrics{m}).std(li) = std(run_baseline(:, m));
        results_thold.(metrics{m}).mean(li) = mean(run_thold(:, m));
        results_thold.(metrics{m}).std(li) = std(run_thold(:, m));
    end
    
    fprintf('\n');
end

%% 결과 출력
fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════╗\n');
fprintf('║                        실험 결과                             ║\n');
fprintf('╚══════════════════════════════════════════════════════════════╝\n\n');

fprintf('%-12s', 'λ_on');
for li = 1:num_lambda
    fprintf('| %-20d', lambda_values(li));
end
fprintf('\n');
fprintf('%s\n', repmat('=', 1, 12 + 22 * num_lambda));

% Mean Delay
fprintf('%-12s', 'Delay (ms)');
for li = 1:num_lambda
    fprintf('| Base: %6.1f±%-6.1f', ...
        results_baseline.delay_mean.mean(li), results_baseline.delay_mean.std(li));
end
fprintf('\n');
fprintf('%-12s', '');
for li = 1:num_lambda
    fprintf('| Thold: %5.1f±%-6.1f', ...
        results_thold.delay_mean.mean(li), results_thold.delay_mean.std(li));
end
fprintf('\n');

% Improvement
fprintf('%-12s', '개선율');
for li = 1:num_lambda
    improvement = (results_baseline.delay_mean.mean(li) - results_thold.delay_mean.mean(li)) ...
                  / results_baseline.delay_mean.mean(li) * 100;
    fprintf('| %+.1f%%              ', improvement);
end
fprintf('\n\n');

% Collision Rate
fprintf('%-12s', 'Collision%%');
for li = 1:num_lambda
    fprintf('| Base: %6.1f±%-6.1f', ...
        results_baseline.collision_rate.mean(li), results_baseline.collision_rate.std(li));
end
fprintf('\n');
fprintf('%-12s', '');
for li = 1:num_lambda
    fprintf('| Thold: %5.1f±%-6.1f', ...
        results_thold.collision_rate.mean(li), results_thold.collision_rate.std(li));
end
fprintf('\n');

% Improvement
fprintf('%-12s', '개선율');
for li = 1:num_lambda
    improvement = (results_baseline.collision_rate.mean(li) - results_thold.collision_rate.mean(li)) ...
                  / results_baseline.collision_rate.mean(li) * 100;
    fprintf('| %+.1f%%              ', improvement);
end
fprintf('\n\n');

% Explicit BSR Ratio
fprintf('%-12s', 'Exp BSR%%');
for li = 1:num_lambda
    fprintf('| Base: %6.1f±%-6.1f', ...
        results_baseline.explicit_bsr_ratio.mean(li), results_baseline.explicit_bsr_ratio.std(li));
end
fprintf('\n');
fprintf('%-12s', '');
for li = 1:num_lambda
    fprintf('| Thold: %5.1f±%-6.1f', ...
        results_thold.explicit_bsr_ratio.mean(li), results_thold.explicit_bsr_ratio.std(li));
end
fprintf('\n\n');

% Throughput
fprintf('%-12s', 'Throughput');
for li = 1:num_lambda
    fprintf('| Base: %6.2f±%-6.2f', ...
        results_baseline.throughput.mean(li), results_baseline.throughput.std(li));
end
fprintf('\n');
fprintf('%-12s', '(Mbps)');
for li = 1:num_lambda
    fprintf('| Thold: %5.2f±%-6.2f', ...
        results_thold.throughput.mean(li), results_thold.throughput.std(li));
end
fprintf('\n\n');

% Completion Rate
fprintf('%-12s', 'Complete%%');
for li = 1:num_lambda
    fprintf('| Base: %6.1f±%-6.1f', ...
        results_baseline.completion_rate.mean(li), results_baseline.completion_rate.std(li));
end
fprintf('\n');
fprintf('%-12s', '');
for li = 1:num_lambda
    fprintf('| Thold: %5.1f±%-6.1f', ...
        results_thold.completion_rate.mean(li), results_thold.completion_rate.std(li));
end
fprintf('\n\n');

%% 그래프 생성
figure('Position', [100, 100, 1400, 900]);
sgtitle(sprintf('\\lambda_{on} Sweep: Baseline vs T_{hold} (10ms)\nsimulation\\_time=%ds, num\\_runs=%d, numSTAs=%d, \\rho=%.1f, \\mu_{on}=%.2fs, RA\\_RU=1', ...
    sim_time, num_runs, num_stas, rho, mu_on), 'FontSize', 12);

x = 1:num_lambda;
bar_width = 0.35;

% 1. Mean Delay
subplot(2, 3, 1);
b1 = bar(x - bar_width/2, results_baseline.delay_mean.mean, bar_width, 'FaceColor', [0.2 0.4 0.8]);
hold on;
b2 = bar(x + bar_width/2, results_thold.delay_mean.mean, bar_width, 'FaceColor', [0.8 0.2 0.2]);
errorbar(x - bar_width/2, results_baseline.delay_mean.mean, results_baseline.delay_mean.std, 'k', 'LineStyle', 'none');
errorbar(x + bar_width/2, results_thold.delay_mean.mean, results_thold.delay_mean.std, 'k', 'LineStyle', 'none');

% 개선율 표시
for i = 1:num_lambda
    improvement = (results_baseline.delay_mean.mean(i) - results_thold.delay_mean.mean(i)) ...
                  / results_baseline.delay_mean.mean(i) * 100;
    max_val = max(results_baseline.delay_mean.mean(i), results_thold.delay_mean.mean(i));
    text(i, max_val * 1.1, sprintf('↓%.0f%%', improvement), 'HorizontalAlignment', 'center', 'FontSize', 9);
end

ylabel('Mean Delay (ms)');
xlabel('\lambda_{on} (pkt/s)');
set(gca, 'XTick', x, 'XTickLabel', lambda_values);
legend([b1, b2], {'Baseline', 'T_{hold}'}, 'Location', 'northwest');
title('Mean Delay');
grid on;

% 2. Collision Rate
subplot(2, 3, 2);
b1 = bar(x - bar_width/2, results_baseline.collision_rate.mean, bar_width, 'FaceColor', [0.2 0.4 0.8]);
hold on;
b2 = bar(x + bar_width/2, results_thold.collision_rate.mean, bar_width, 'FaceColor', [0.8 0.2 0.2]);
errorbar(x - bar_width/2, results_baseline.collision_rate.mean, results_baseline.collision_rate.std, 'k', 'LineStyle', 'none');
errorbar(x + bar_width/2, results_thold.collision_rate.mean, results_thold.collision_rate.std, 'k', 'LineStyle', 'none');

for i = 1:num_lambda
    improvement = (results_baseline.collision_rate.mean(i) - results_thold.collision_rate.mean(i)) ...
                  / results_baseline.collision_rate.mean(i) * 100;
    max_val = max(results_baseline.collision_rate.mean(i), results_thold.collision_rate.mean(i));
    text(i, max_val * 1.1, sprintf('↓%.0f%%', improvement), 'HorizontalAlignment', 'center', 'FontSize', 9);
end

ylabel('Collision Rate (%)');
xlabel('\lambda_{on} (pkt/s)');
set(gca, 'XTick', x, 'XTickLabel', lambda_values);
legend([b1, b2], {'Baseline', 'T_{hold}'}, 'Location', 'northwest');
title('Collision Rate');
grid on;

% 3. BSR Count (Stacked)
subplot(2, 3, 3);
% 각 lambda에 대해 2개의 stacked bar: [T_hold, Baseline]
% x축 위치: lambda별로 2개씩
num_bars = num_lambda * 2;
x_positions = [];
for li = 1:num_lambda
    x_positions = [x_positions, li - 0.2, li + 0.2];
end

% Stacked data: [Implicit; Explicit] for each bar
stacked_implicit = zeros(1, num_bars);
stacked_explicit = zeros(1, num_bars);
bar_colors_implicit = zeros(num_bars, 3);
bar_colors_explicit = zeros(num_bars, 3);

for li = 1:num_lambda
    % T_hold (홀수 인덱스)
    idx_thold = (li-1)*2 + 1;
    stacked_implicit(idx_thold) = results_thold.implicit_bsr_count.mean(li);
    stacked_explicit(idx_thold) = results_thold.explicit_bsr_count.mean(li);
    
    % Baseline (짝수 인덱스)
    idx_base = (li-1)*2 + 2;
    stacked_implicit(idx_base) = results_baseline.implicit_bsr_count.mean(li);
    stacked_explicit(idx_base) = results_baseline.explicit_bsr_count.mean(li);
end

% Stacked bar plot
bsr_stack = [stacked_implicit; stacked_explicit]';
b = bar(x_positions, bsr_stack, 0.35, 'stacked');

% 색상 설정 (T_hold: 빨강 계열, Baseline: 파랑 계열)
% Implicit은 연한 색, Explicit은 진한 색
for li = 1:num_lambda
    idx_thold = (li-1)*2 + 1;
    idx_base = (li-1)*2 + 2;
    
    % T_hold bars
    b(1).FaceColor = 'flat';
    b(2).FaceColor = 'flat';
    b(1).CData(idx_thold, :) = [0.8 0.4 0.4];  % T_hold Implicit (연한 빨강)
    b(2).CData(idx_thold, :) = [0.8 0.2 0.2];  % T_hold Explicit (진한 빨강)
    
    % Baseline bars
    b(1).CData(idx_base, :) = [0.4 0.4 0.8];   % Base Implicit (연한 파랑)
    b(2).CData(idx_base, :) = [0.2 0.4 0.8];   % Base Explicit (진한 파랑)
end

% 숫자 표시
hold on;
for li = 1:num_lambda
    idx_thold = (li-1)*2 + 1;
    idx_base = (li-1)*2 + 2;
    total_thold = stacked_implicit(idx_thold) + stacked_explicit(idx_thold);
    total_base = stacked_implicit(idx_base) + stacked_explicit(idx_base);
    text(x_positions(idx_thold), total_thold, sprintf('%.0f', total_thold), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 8);
    text(x_positions(idx_base), total_base, sprintf('%.0f', total_base), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 8);
end

ylabel('BSR Count');
xlabel('\lambda_{on} (pkt/s)');
set(gca, 'XTick', 1:num_lambda, 'XTickLabel', lambda_values);
% 범례용 더미
hold on;
h1 = bar(nan, nan, 'FaceColor', [0.8 0.4 0.4]);
h2 = bar(nan, nan, 'FaceColor', [0.8 0.2 0.2]);
h3 = bar(nan, nan, 'FaceColor', [0.4 0.4 0.8]);
h4 = bar(nan, nan, 'FaceColor', [0.2 0.4 0.8]);
legend([h1, h2, h3, h4], {'T_{hold} Implicit', 'T_{hold} Explicit', 'Base Implicit', 'Base Explicit'}, 'Location', 'northwest');
title('BSR Count (Stacked)');
grid on;

% 4. Explicit BSR Ratio
subplot(2, 3, 4);
b1 = bar(x - bar_width/2, results_baseline.explicit_bsr_ratio.mean, bar_width, 'FaceColor', [0.2 0.4 0.8]);
hold on;
b2 = bar(x + bar_width/2, results_thold.explicit_bsr_ratio.mean, bar_width, 'FaceColor', [0.8 0.2 0.2]);
errorbar(x - bar_width/2, results_baseline.explicit_bsr_ratio.mean, results_baseline.explicit_bsr_ratio.std, 'k', 'LineStyle', 'none');
errorbar(x + bar_width/2, results_thold.explicit_bsr_ratio.mean, results_thold.explicit_bsr_ratio.std, 'k', 'LineStyle', 'none');
ylabel('Explicit BSR Ratio (%)');
xlabel('\lambda_{on} (pkt/s)');
set(gca, 'XTick', x, 'XTickLabel', lambda_values);
legend([b1, b2], {'Baseline', 'T_{hold}'}, 'Location', 'northeast');
title('Explicit BSR Ratio');
grid on;

% 5. Throughput
subplot(2, 3, 5);
b1 = bar(x - bar_width/2, results_baseline.throughput.mean, bar_width, 'FaceColor', [0.2 0.4 0.8]);
hold on;
b2 = bar(x + bar_width/2, results_thold.throughput.mean, bar_width, 'FaceColor', [0.8 0.2 0.2]);
errorbar(x - bar_width/2, results_baseline.throughput.mean, results_baseline.throughput.std, 'k', 'LineStyle', 'none');
errorbar(x + bar_width/2, results_thold.throughput.mean, results_thold.throughput.std, 'k', 'LineStyle', 'none');
ylabel('Throughput (Mbps)');
xlabel('\lambda_{on} (pkt/s)');
set(gca, 'XTick', x, 'XTickLabel', lambda_values);
legend([b1, b2], {'Baseline', 'T_{hold}'}, 'Location', 'northwest');
title('Throughput');
grid on;

% 6. Packet Completion Rate
subplot(2, 3, 6);
b1 = bar(x - bar_width/2, results_baseline.completion_rate.mean, bar_width, 'FaceColor', [0.2 0.4 0.8]);
hold on;
b2 = bar(x + bar_width/2, results_thold.completion_rate.mean, bar_width, 'FaceColor', [0.8 0.2 0.2]);
errorbar(x - bar_width/2, results_baseline.completion_rate.mean, results_baseline.completion_rate.std, 'k', 'LineStyle', 'none');
errorbar(x + bar_width/2, results_thold.completion_rate.mean, results_thold.completion_rate.std, 'k', 'LineStyle', 'none');
ylabel('Packet Completion Rate (%)');
xlabel('\lambda_{on} (pkt/s)');
set(gca, 'XTick', x, 'XTickLabel', lambda_values);
legend([b1, b2], {'Baseline', 'T_{hold}'}, 'Location', 'southwest');
title('Packet Completion Rate');
ylim([90, 100]);
grid on;

% 그래프 저장
saveas(gcf, 'results/lambda_sweep_comparison.png');
saveas(gcf, 'results/lambda_sweep_comparison.fig');
fprintf('그래프 저장 완료: results/lambda_sweep_comparison.png\n');

%% 결과 저장
save('results/lambda_sweep_results.mat', 'results_baseline', 'results_thold', ...
     'lambda_values', 'num_runs', 'sim_time', 'num_stas', 'rho', 'mu_on', 'thold_value');
fprintf('결과 저장 완료: results/lambda_sweep_results.mat\n');

fprintf('\n실험 완료!\n');