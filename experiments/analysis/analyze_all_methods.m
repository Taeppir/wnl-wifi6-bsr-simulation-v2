%% analyze_all_methods_v3.m
% M0, M1(5), M2 통합 분석 - Line 추이 위주
%
% Figure 구성:
%   [지연] 1: Delay 추이 (Mean 실선 + P90 점선)
%          2: Delay CDF
%          3: Delay Distribution
%          4: Delay Decomposition
%   [T_hold 효과] 5: Phantom 추이
%                6: Hit Rate 추이
%                7: Trade-off
%   [자원 효율] 8: Throughput 추이
%              9: Channel Utilization 추이
%             10: Completion Rate 추이
%   [UORA/BSR] 11: UORA Collision 추이
%             12: UORA Attempts 추이
%             13: BSR Count
%   [공정성] 14: Fairness 추이

clear; clc;
fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════════╗\n');
fprintf('║            M0 / M1(5) / M2 통합 분석 v3                           ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════╝\n\n');

%% 데이터 로드
fprintf('[데이터 로드]\n');

m0m1_file = 'results/main_m0_m1/results.mat';
m2_file = 'results/main_m2/results.mat';

load(m0m1_file, 'results'); results_m0m1 = results;
fprintf('  ✓ M0/M1 결과 로드\n');
load(m2_file, 'results'); results_m2 = results;
fprintf('  ✓ M2 결과 로드\n');

%% 설정
scenario_names = {'A', 'B', 'C'};
scenario_desc = {'VoIP-like', 'Video-like', 'IoT-like'};
thold_values = [30, 50, 70];
num_seeds = 3;

% 색상
colors.Baseline = [0.5 0.5 0.5];
colors.M0 = [0.2 0.4 0.8];
colors.M1_5 = [0.9 0.6 0.1];
colors.M2 = [0.2 0.7 0.3];

output_dir = 'results/figures_v3';
if ~exist(output_dir, 'dir'), mkdir(output_dir); end

%% ═══════════════════════════════════════════════════════════════════════
%  [지연] Figure 1: Delay 추이 (Mean 실선 + P90 점선)
%  ═══════════════════════════════════════════════════════════════════════
figure('Name', 'Fig 1: Delay Trend', 'Position', [100 100 1200 400]);

for sc_idx = 1:3
    sc = scenario_names{sc_idx};
    subplot(1, 3, sc_idx);
    
    m0_mean = zeros(1,3); m1_mean = zeros(1,3); m2_mean = zeros(1,3);
    m0_p90 = zeros(1,3); m1_p90 = zeros(1,3); m2_p90 = zeros(1,3);
    
    for th_idx = 1:3
        th = thold_values(th_idx);
        [m0_mean(th_idx), ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'delay.mean_ms', num_seeds);
        [m1_mean(th_idx), ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'delay.mean_ms', num_seeds);
        [m2_mean(th_idx), ~] = get_metric_avg(results_m2, sc, th, 'M2', 'delay.mean_ms', num_seeds);
        [m0_p90(th_idx), ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'delay.p90_ms', num_seeds);
        [m1_p90(th_idx), ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'delay.p90_ms', num_seeds);
        [m2_p90(th_idx), ~] = get_metric_avg(results_m2, sc, th, 'M2', 'delay.p90_ms', num_seeds);
    end
    
    [base_mean, ~] = get_metric_avg(results_m0m1, sc, 0, 'Baseline', 'delay.mean_ms', num_seeds);
    [base_p90, ~] = get_metric_avg(results_m0m1, sc, 0, 'Baseline', 'delay.p90_ms', num_seeds);
    
    % Mean (실선)
    plot(thold_values, m0_mean, '-o', 'Color', colors.M0, 'LineWidth', 2, 'MarkerFaceColor', colors.M0);
    hold on;
    plot(thold_values, m1_mean, '-s', 'Color', colors.M1_5, 'LineWidth', 2, 'MarkerFaceColor', colors.M1_5);
    plot(thold_values, m2_mean, '-^', 'Color', colors.M2, 'LineWidth', 2, 'MarkerFaceColor', colors.M2);
    
    % P90 (점선)
    plot(thold_values, m0_p90, '--o', 'Color', colors.M0, 'LineWidth', 1.5, 'MarkerSize', 5);
    plot(thold_values, m1_p90, '--s', 'Color', colors.M1_5, 'LineWidth', 1.5, 'MarkerSize', 5);
    plot(thold_values, m2_p90, '--^', 'Color', colors.M2, 'LineWidth', 1.5, 'MarkerSize', 5);
    
    % Baseline (수평선)
    yline(base_mean, '-', 'Color', colors.Baseline, 'LineWidth', 1.5);
    yline(base_p90, '--', 'Color', colors.Baseline, 'LineWidth', 1.5);
    hold off;
    
    xlabel('T_{hold} (ms)'); ylabel('Delay (ms)');
    title(sprintf('%s (%s)', sc, scenario_desc{sc_idx}));
    if sc_idx == 1
        legend({'M0 Mean', 'M1(5) Mean', 'M2 Mean', 'M0 P90', 'M1(5) P90', 'M2 P90', 'Base Mean', 'Base P90'}, ...
            'Location', 'eastoutside', 'FontSize', 7);
    end
    xlim([25 75]); grid on;
end
sgtitle('Figure 1: Delay 추이 (실선=Mean, 점선=P90)');

%% Figure 2: Delay CDF (3x3)
figure('Name', 'Fig 2: Delay CDF', 'Position', [100 100 1200 800]);

for sc_idx = 1:3
    sc = scenario_names{sc_idx};
    for th_idx = 1:3
        th = thold_values(th_idx);
        subplot(3, 3, (sc_idx-1)*3 + th_idx);
        
        % Baseline
        field = sprintf('%s_Baseline_s1', sc);
        if isfield(results_m0m1.runs, field)
            [x, f] = manual_cdf(results_m0m1.runs.(field).delay.all_ms);
            plot(x, f, '-', 'Color', colors.Baseline, 'LineWidth', 2); hold on;
        end
        
        % M0
        field = sprintf('%s_T%d_M0_s1', sc, th);
        if isfield(results_m0m1.runs, field)
            [x, f] = manual_cdf(results_m0m1.runs.(field).delay.all_ms);
            plot(x, f, '-', 'Color', colors.M0, 'LineWidth', 2);
        end
        
        % M1(5)
        field = sprintf('%s_T%d_M1_5_s1', sc, th);
        if isfield(results_m0m1.runs, field)
            [x, f] = manual_cdf(results_m0m1.runs.(field).delay.all_ms);
            plot(x, f, '-', 'Color', colors.M1_5, 'LineWidth', 2);
        end
        
        % M2
        field = sprintf('%s_T%d_M2_s1', sc, th);
        if isfield(results_m2.runs, field)
            [x, f] = manual_cdf(results_m2.runs.(field).delay.all_ms);
            plot(x, f, '-', 'Color', colors.M2, 'LineWidth', 2);
        end
        
        yline(0.9, ':', 'Color', [0.5 0.5 0.5]);
        hold off;
        
        xlabel('Delay (ms)'); ylabel('CDF');
        title(sprintf('%s - T_{hold}=%dms', sc, th));
        if sc_idx == 1 && th_idx == 1
            legend({'Baseline', 'M0', 'M1(5)', 'M2'}, 'Location', 'southeast');
        end
        xlim([0 300]); ylim([0 1]); grid on;
    end
end
sgtitle('Figure 2: Delay CDF');

%% Figure 3: Delay Distribution (3x3)
figure('Name', 'Fig 3: Delay Distribution', 'Position', [100 100 1200 800]);

for sc_idx = 1:3
    sc = scenario_names{sc_idx};
    for th_idx = 1:3
        th = thold_values(th_idx);
        subplot(3, 3, (sc_idx-1)*3 + th_idx);
        
        methods = {'Baseline', 'M0', 'M1(5)', 'M2'};
        means = zeros(1,4); stds = zeros(1,4);
        p10s = zeros(1,4); p90s = zeros(1,4);
        
        for m = 1:4
            if m == 1, res = results_m0m1; th_use = 0;
            elseif m == 4, res = results_m2; th_use = th;
            else, res = results_m0m1; th_use = th; end
            
            [means(m), ~] = get_metric_avg(res, sc, th_use, methods{m}, 'delay.mean_ms', num_seeds);
            [stds(m), ~] = get_metric_avg(res, sc, th_use, methods{m}, 'delay.std_ms', num_seeds);
            [p10s(m), ~] = get_metric_avg(res, sc, th_use, methods{m}, 'delay.p10_ms', num_seeds);
            [p90s(m), ~] = get_metric_avg(res, sc, th_use, methods{m}, 'delay.p90_ms', num_seeds);
        end
        
        bar_colors = [colors.Baseline; colors.M0; colors.M1_5; colors.M2];
        for m = 1:4
            bar(m, means(m), 'FaceColor', bar_colors(m,:)); hold on;
        end
        errorbar(1:4, means, stds, 'k', 'linestyle', 'none', 'LineWidth', 1.5);
        for m = 1:4
            plot([m-0.2 m+0.2], [p10s(m) p10s(m)], '--', 'Color', bar_colors(m,:), 'LineWidth', 1);
            plot([m-0.2 m+0.2], [p90s(m) p90s(m)], '--', 'Color', bar_colors(m,:), 'LineWidth', 1);
        end
        hold off;
        
        set(gca, 'XTick', 1:4, 'XTickLabel', {'Base', 'M0', 'M1', 'M2'});
        ylabel('Delay (ms)');
        title(sprintf('%s - T_{hold}=%dms', sc, th));
        grid on;
    end
end
sgtitle('Figure 3: Delay Distribution (Bar=Mean, ErrorBar=Std, Dash=P10/P90)');

%% Figure 4: Delay Decomposition (3x3)
figure('Name', 'Fig 4: Delay Decomposition', 'Position', [100 100 1200 800]);

for sc_idx = 1:3
    sc = scenario_names{sc_idx};
    for th_idx = 1:3
        th = thold_values(th_idx);
        subplot(3, 3, (sc_idx-1)*3 + th_idx);
        
        methods = {'Baseline', 'M0', 'M1(5)', 'M2'};
        init = zeros(1,4); uora = zeros(1,4); sa = zeros(1,4);
        
        for m = 1:4
            if m == 1, res = results_m0m1; th_use = 0;
            elseif m == 4, res = results_m2; th_use = th;
            else, res = results_m0m1; th_use = th; end
            
            [init(m), ~] = get_metric_avg(res, sc, th_use, methods{m}, 'delay_decomp.initial_wait.mean_ms', num_seeds);
            [uora(m), ~] = get_metric_avg(res, sc, th_use, methods{m}, 'delay_decomp.uora_contention.mean_ms', num_seeds);
            [sa(m), ~] = get_metric_avg(res, sc, th_use, methods{m}, 'delay_decomp.sa_wait.mean_ms', num_seeds);
        end
        
        b = bar([init; uora; sa]', 'stacked');
        b(1).FaceColor = [0.3 0.6 0.9];
        b(2).FaceColor = [0.9 0.4 0.4];
        b(3).FaceColor = [0.5 0.8 0.5];
        
        set(gca, 'XTickLabel', {'Base', 'M0', 'M1', 'M2'});
        ylabel('Delay (ms)');
        title(sprintf('%s - T_{hold}=%dms', sc, th));
        if sc_idx == 1 && th_idx == 1
            legend({'Initial Wait', 'UORA Cont.', 'SA Wait'}, 'Location', 'northeast');
        end
        grid on;
    end
end
sgtitle('Figure 4: Delay Decomposition');

%% ═══════════════════════════════════════════════════════════════════════
%  [T_hold 효과] Figure 5: Phantom 추이
%  ═══════════════════════════════════════════════════════════════════════
figure('Name', 'Fig 5: Phantom', 'Position', [100 100 1200 400]);

for sc_idx = 1:3
    sc = scenario_names{sc_idx};
    subplot(1, 3, sc_idx);
    
    m0_ph = zeros(1,3); m1_ph = zeros(1,3); m2_ph = zeros(1,3);
    for th_idx = 1:3
        th = thold_values(th_idx);
        [m0_ph(th_idx), ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'thold.phantoms', num_seeds);
        [m1_ph(th_idx), ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'thold.phantoms', num_seeds);
        [m2_ph(th_idx), ~] = get_metric_avg(results_m2, sc, th, 'M2', 'thold.phantoms', num_seeds);
    end
    
    plot(thold_values, m0_ph, '-o', 'Color', colors.M0, 'LineWidth', 2, 'MarkerFaceColor', colors.M0);
    hold on;
    plot(thold_values, m1_ph, '-s', 'Color', colors.M1_5, 'LineWidth', 2, 'MarkerFaceColor', colors.M1_5);
    plot(thold_values, m2_ph, '-^', 'Color', colors.M2, 'LineWidth', 2, 'MarkerFaceColor', colors.M2);
    hold off;
    
    xlabel('T_{hold} (ms)'); ylabel('Phantom Count');
    title(sprintf('%s (%s)', sc, scenario_desc{sc_idx}));
    if sc_idx == 1, legend({'M0', 'M1(5)', 'M2'}, 'Location', 'best'); end
    xlim([25 75]); grid on;
end
sgtitle('Figure 5: Phantom Count 추이');

%% Figure 6: Hit Rate 추이
figure('Name', 'Fig 6: Hit Rate', 'Position', [100 100 1200 400]);

for sc_idx = 1:3
    sc = scenario_names{sc_idx};
    subplot(1, 3, sc_idx);
    
    m0_hr = zeros(1,3); m1_hr = zeros(1,3); m2_hr = zeros(1,3);
    for th_idx = 1:3
        th = thold_values(th_idx);
        [m0_hr(th_idx), ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'thold.hit_rate', num_seeds);
        [m1_hr(th_idx), ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'thold.hit_rate', num_seeds);
        [m2_hr(th_idx), ~] = get_metric_avg(results_m2, sc, th, 'M2', 'thold.hit_rate', num_seeds);
    end
    
    plot(thold_values, m0_hr*100, '-o', 'Color', colors.M0, 'LineWidth', 2, 'MarkerFaceColor', colors.M0);
    hold on;
    plot(thold_values, m1_hr*100, '-s', 'Color', colors.M1_5, 'LineWidth', 2, 'MarkerFaceColor', colors.M1_5);
    plot(thold_values, m2_hr*100, '-^', 'Color', colors.M2, 'LineWidth', 2, 'MarkerFaceColor', colors.M2);
    hold off;
    
    xlabel('T_{hold} (ms)'); ylabel('Hit Rate (%)');
    title(sprintf('%s (%s)', sc, scenario_desc{sc_idx}));
    if sc_idx == 1, legend({'M0', 'M1(5)', 'M2'}, 'Location', 'best'); end
    xlim([25 75]); ylim([0 100]); grid on;
end
sgtitle('Figure 6: Hit Rate 추이');

%% Figure 7: Trade-off (3x3)
figure('Name', 'Fig 7: Trade-off', 'Position', [100 100 1200 800]);

for sc_idx = 1:3
    sc = scenario_names{sc_idx};
    for th_idx = 1:3
        th = thold_values(th_idx);
        subplot(3, 3, (sc_idx-1)*3 + th_idx);
        
        [m0_d, ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'delay.mean_ms', num_seeds);
        [m1_d, ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'delay.mean_ms', num_seeds);
        [m2_d, ~] = get_metric_avg(results_m2, sc, th, 'M2', 'delay.mean_ms', num_seeds);
        [m0_ph, ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'thold.phantoms', num_seeds);
        [m1_ph, ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'thold.phantoms', num_seeds);
        [m2_ph, ~] = get_metric_avg(results_m2, sc, th, 'M2', 'thold.phantoms', num_seeds);
        [base_d, ~] = get_metric_avg(results_m0m1, sc, 0, 'Baseline', 'delay.mean_ms', num_seeds);
        
        scatter(m0_ph, m0_d, 150, colors.M0, 'filled', 'o'); hold on;
        scatter(m1_ph, m1_d, 150, colors.M1_5, 'filled', 's');
        scatter(m2_ph, m2_d, 150, colors.M2, 'filled', '^');
        yline(base_d, '--', 'Color', colors.Baseline, 'LineWidth', 1.5);
        
        text(m0_ph, m0_d+5, 'M0', 'HorizontalAlignment', 'center', 'FontSize', 8);
        text(m1_ph, m1_d+5, 'M1', 'HorizontalAlignment', 'center', 'FontSize', 8);
        text(m2_ph, m2_d+5, 'M2', 'HorizontalAlignment', 'center', 'FontSize', 8);
        hold off;
        
        xlabel('Phantom'); ylabel('Delay (ms)');
        title(sprintf('%s - T_{hold}=%dms', sc, th));
        grid on;
    end
end
sgtitle('Figure 7: Trade-off (Delay vs Phantom)');

%% ═══════════════════════════════════════════════════════════════════════
%  [자원 효율] Figure 8: Throughput 추이
%  ═══════════════════════════════════════════════════════════════════════
figure('Name', 'Fig 8: Throughput', 'Position', [100 100 1200 400]);

for sc_idx = 1:3
    sc = scenario_names{sc_idx};
    subplot(1, 3, sc_idx);
    
    m0_t = zeros(1,3); m1_t = zeros(1,3); m2_t = zeros(1,3);
    for th_idx = 1:3
        th = thold_values(th_idx);
        [m0_t(th_idx), ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'throughput.total_mbps', num_seeds);
        [m1_t(th_idx), ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'throughput.total_mbps', num_seeds);
        [m2_t(th_idx), ~] = get_metric_avg(results_m2, sc, th, 'M2', 'throughput.total_mbps', num_seeds);
    end
    [base_t, ~] = get_metric_avg(results_m0m1, sc, 0, 'Baseline', 'throughput.total_mbps', num_seeds);
    
    plot(thold_values, m0_t, '-o', 'Color', colors.M0, 'LineWidth', 2, 'MarkerFaceColor', colors.M0);
    hold on;
    plot(thold_values, m1_t, '-s', 'Color', colors.M1_5, 'LineWidth', 2, 'MarkerFaceColor', colors.M1_5);
    plot(thold_values, m2_t, '-^', 'Color', colors.M2, 'LineWidth', 2, 'MarkerFaceColor', colors.M2);
    yline(base_t, '--', 'Baseline', 'Color', colors.Baseline, 'LineWidth', 1.5);
    hold off;
    
    xlabel('T_{hold} (ms)'); ylabel('Throughput (Mbps)');
    title(sprintf('%s (%s)', sc, scenario_desc{sc_idx}));
    if sc_idx == 1, legend({'M0', 'M1(5)', 'M2', 'Baseline'}, 'Location', 'best'); end
    xlim([25 75]); grid on;
end
sgtitle('Figure 8: Throughput 추이');

%% Figure 9: Channel Utilization 추이
figure('Name', 'Fig 9: Channel Util', 'Position', [100 100 1200 400]);

for sc_idx = 1:3
    sc = scenario_names{sc_idx};
    subplot(1, 3, sc_idx);
    
    m0_u = zeros(1,3); m1_u = zeros(1,3); m2_u = zeros(1,3);
    for th_idx = 1:3
        th = thold_values(th_idx);
        [m0_u(th_idx), ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'throughput.channel_utilization', num_seeds);
        [m1_u(th_idx), ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'throughput.channel_utilization', num_seeds);
        [m2_u(th_idx), ~] = get_metric_avg(results_m2, sc, th, 'M2', 'throughput.channel_utilization', num_seeds);
    end
    [base_u, ~] = get_metric_avg(results_m0m1, sc, 0, 'Baseline', 'throughput.channel_utilization', num_seeds);
    
    plot(thold_values, m0_u*100, '-o', 'Color', colors.M0, 'LineWidth', 2, 'MarkerFaceColor', colors.M0);
    hold on;
    plot(thold_values, m1_u*100, '-s', 'Color', colors.M1_5, 'LineWidth', 2, 'MarkerFaceColor', colors.M1_5);
    plot(thold_values, m2_u*100, '-^', 'Color', colors.M2, 'LineWidth', 2, 'MarkerFaceColor', colors.M2);
    yline(base_u*100, '--', 'Baseline', 'Color', colors.Baseline, 'LineWidth', 1.5);
    hold off;
    
    xlabel('T_{hold} (ms)'); ylabel('Channel Utilization (%)');
    title(sprintf('%s (%s)', sc, scenario_desc{sc_idx}));
    if sc_idx == 1, legend({'M0', 'M1(5)', 'M2', 'Baseline'}, 'Location', 'best'); end
    xlim([25 75]); ylim([0 100]); grid on;
end
sgtitle('Figure 9: Channel Utilization 추이');

%% Figure 10: Completion Rate 추이
figure('Name', 'Fig 10: Completion', 'Position', [100 100 1200 400]);

for sc_idx = 1:3
    sc = scenario_names{sc_idx};
    subplot(1, 3, sc_idx);
    
    m0_c = zeros(1,3); m1_c = zeros(1,3); m2_c = zeros(1,3);
    for th_idx = 1:3
        th = thold_values(th_idx);
        [m0_c(th_idx), ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'packets.completion_rate', num_seeds);
        [m1_c(th_idx), ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'packets.completion_rate', num_seeds);
        [m2_c(th_idx), ~] = get_metric_avg(results_m2, sc, th, 'M2', 'packets.completion_rate', num_seeds);
    end
    [base_c, ~] = get_metric_avg(results_m0m1, sc, 0, 'Baseline', 'packets.completion_rate', num_seeds);
    
    plot(thold_values, m0_c*100, '-o', 'Color', colors.M0, 'LineWidth', 2, 'MarkerFaceColor', colors.M0);
    hold on;
    plot(thold_values, m1_c*100, '-s', 'Color', colors.M1_5, 'LineWidth', 2, 'MarkerFaceColor', colors.M1_5);
    plot(thold_values, m2_c*100, '-^', 'Color', colors.M2, 'LineWidth', 2, 'MarkerFaceColor', colors.M2);
    yline(base_c*100, '--', 'Baseline', 'Color', colors.Baseline, 'LineWidth', 1.5);
    hold off;
    
    xlabel('T_{hold} (ms)'); ylabel('Completion Rate (%)');
    title(sprintf('%s (%s)', sc, scenario_desc{sc_idx}));
    if sc_idx == 1, legend({'M0', 'M1(5)', 'M2', 'Baseline'}, 'Location', 'best'); end
    xlim([25 75]); ylim([0 100]); grid on;
end
sgtitle('Figure 10: Completion Rate 추이');

%% ═══════════════════════════════════════════════════════════════════════
%  [UORA/BSR] Figure 11: UORA Collision Rate 추이
%  ═══════════════════════════════════════════════════════════════════════
figure('Name', 'Fig 11: UORA Collision', 'Position', [100 100 1200 400]);

for sc_idx = 1:3
    sc = scenario_names{sc_idx};
    subplot(1, 3, sc_idx);
    
    m0_coll = zeros(1,3); m1_coll = zeros(1,3); m2_coll = zeros(1,3);
    for th_idx = 1:3
        th = thold_values(th_idx);
        [m0_coll(th_idx), ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'uora.collision_rate', num_seeds);
        [m1_coll(th_idx), ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'uora.collision_rate', num_seeds);
        [m2_coll(th_idx), ~] = get_metric_avg(results_m2, sc, th, 'M2', 'uora.collision_rate', num_seeds);
    end
    [base_coll, ~] = get_metric_avg(results_m0m1, sc, 0, 'Baseline', 'uora.collision_rate', num_seeds);
    
    plot(thold_values, m0_coll*100, '-o', 'Color', colors.M0, 'LineWidth', 2, 'MarkerFaceColor', colors.M0);
    hold on;
    plot(thold_values, m1_coll*100, '-s', 'Color', colors.M1_5, 'LineWidth', 2, 'MarkerFaceColor', colors.M1_5);
    plot(thold_values, m2_coll*100, '-^', 'Color', colors.M2, 'LineWidth', 2, 'MarkerFaceColor', colors.M2);
    yline(base_coll*100, '--', 'Baseline', 'Color', colors.Baseline, 'LineWidth', 1.5);
    hold off;
    
    xlabel('T_{hold} (ms)'); ylabel('Collision Rate (%)');
    title(sprintf('%s (%s)', sc, scenario_desc{sc_idx}));
    if sc_idx == 1, legend({'M0', 'M1(5)', 'M2', 'Baseline'}, 'Location', 'best'); end
    xlim([25 75]); ylim([0 100]); grid on;
end
sgtitle('Figure 11: UORA Collision Rate 추이');

%% Figure 12: UORA Attempts 추이
figure('Name', 'Fig 12: UORA Attempts', 'Position', [100 100 1200 400]);

for sc_idx = 1:3
    sc = scenario_names{sc_idx};
    subplot(1, 3, sc_idx);
    
    m0_a = zeros(1,3); m1_a = zeros(1,3); m2_a = zeros(1,3);
    for th_idx = 1:3
        th = thold_values(th_idx);
        [m0_a(th_idx), ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'uora.total_attempts', num_seeds);
        [m1_a(th_idx), ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'uora.total_attempts', num_seeds);
        [m2_a(th_idx), ~] = get_metric_avg(results_m2, sc, th, 'M2', 'uora.total_attempts', num_seeds);
    end
    [base_a, ~] = get_metric_avg(results_m0m1, sc, 0, 'Baseline', 'uora.total_attempts', num_seeds);
    
    plot(thold_values, m0_a, '-o', 'Color', colors.M0, 'LineWidth', 2, 'MarkerFaceColor', colors.M0);
    hold on;
    plot(thold_values, m1_a, '-s', 'Color', colors.M1_5, 'LineWidth', 2, 'MarkerFaceColor', colors.M1_5);
    plot(thold_values, m2_a, '-^', 'Color', colors.M2, 'LineWidth', 2, 'MarkerFaceColor', colors.M2);
    yline(base_a, '--', 'Baseline', 'Color', colors.Baseline, 'LineWidth', 1.5);
    hold off;
    
    xlabel('T_{hold} (ms)'); ylabel('UORA Attempts');
    title(sprintf('%s (%s)', sc, scenario_desc{sc_idx}));
    if sc_idx == 1, legend({'M0', 'M1(5)', 'M2', 'Baseline'}, 'Location', 'best'); end
    xlim([25 75]); grid on;
end
sgtitle('Figure 12: UORA Attempts 추이');

%% Figure 13: BSR Count (Stacked, 3x3)
figure('Name', 'Fig 13: BSR Count', 'Position', [100 100 1200 800]);

for sc_idx = 1:3
    sc = scenario_names{sc_idx};
    for th_idx = 1:3
        th = thold_values(th_idx);
        subplot(3, 3, (sc_idx-1)*3 + th_idx);
        
        methods = {'Baseline', 'M0', 'M1(5)', 'M2'};
        impl = zeros(1,4); expl = zeros(1,4);
        
        for m = 1:4
            if m == 1, res = results_m0m1; th_use = 0;
            elseif m == 4, res = results_m2; th_use = th;
            else, res = results_m0m1; th_use = th; end
            
            [impl(m), ~] = get_metric_avg(res, sc, th_use, methods{m}, 'bsr.implicit_count', num_seeds);
            [expl(m), ~] = get_metric_avg(res, sc, th_use, methods{m}, 'bsr.explicit_count', num_seeds);
        end
        
        b = bar([impl; expl]', 'stacked');
        b(1).FaceColor = [0.4 0.6 0.8];
        b(2).FaceColor = [0.9 0.5 0.3];
        
        set(gca, 'XTickLabel', {'Base', 'M0', 'M1', 'M2'});
        ylabel('BSR Count');
        title(sprintf('%s - T_{hold}=%dms', sc, th));
        if sc_idx == 1 && th_idx == 1
            legend({'Implicit', 'Explicit'}, 'Location', 'northeast');
        end
        grid on;
    end
end
sgtitle('Figure 13: BSR Count (Implicit + Explicit)');

%% ═══════════════════════════════════════════════════════════════════════
%  [공정성] Figure 14: Fairness 추이
%  ═══════════════════════════════════════════════════════════════════════
figure('Name', 'Fig 14: Fairness', 'Position', [100 100 1200 400]);

for sc_idx = 1:3
    sc = scenario_names{sc_idx};
    subplot(1, 3, sc_idx);
    
    m0_f = zeros(1,3); m1_f = zeros(1,3); m2_f = zeros(1,3);
    for th_idx = 1:3
        th = thold_values(th_idx);
        [m0_f(th_idx), ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'fairness.jain_index', num_seeds);
        [m1_f(th_idx), ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'fairness.jain_index', num_seeds);
        [m2_f(th_idx), ~] = get_metric_avg(results_m2, sc, th, 'M2', 'fairness.jain_index', num_seeds);
    end
    [base_f, ~] = get_metric_avg(results_m0m1, sc, 0, 'Baseline', 'fairness.jain_index', num_seeds);
    
    plot(thold_values, m0_f, '-o', 'Color', colors.M0, 'LineWidth', 2, 'MarkerFaceColor', colors.M0);
    hold on;
    plot(thold_values, m1_f, '-s', 'Color', colors.M1_5, 'LineWidth', 2, 'MarkerFaceColor', colors.M1_5);
    plot(thold_values, m2_f, '-^', 'Color', colors.M2, 'LineWidth', 2, 'MarkerFaceColor', colors.M2);
    yline(base_f, '--', 'Baseline', 'Color', colors.Baseline, 'LineWidth', 1.5);
    hold off;
    
    xlabel('T_{hold} (ms)'); ylabel('Jain''s Fairness Index');
    title(sprintf('%s (%s)', sc, scenario_desc{sc_idx}));
    if sc_idx == 1, legend({'M0', 'M1(5)', 'M2', 'Baseline'}, 'Location', 'best'); end
    xlim([25 75]); ylim([0 1]); grid on;
end
sgtitle('Figure 14: Fairness 추이');

%% Figure 저장
for i = 1:14
    saveas(figure(i), fullfile(output_dir, sprintf('fig%02d.png', i)));
end

fprintf('\n[완료] 14개 Figure 저장: %s/\n', output_dir);

%% ═══════════════════════════════════════════════════════════════════════
%  Helper Functions
%  ═══════════════════════════════════════════════════════════════════════

function [avg, sd] = get_metric_avg(results, scenario, thold_ms, method, metric_path, num_seeds)
    values = [];
    for s = 1:num_seeds
        if strcmp(method, 'Baseline')
            field_name = sprintf('%s_Baseline_s%d', scenario, s);
        elseif strcmp(method, 'M1(5)')
            field_name = sprintf('%s_T%d_M1_5_s%d', scenario, thold_ms, s);
        else
            field_name = sprintf('%s_T%d_%s_s%d', scenario, thold_ms, method, s);
        end
        
        if isfield(results.runs, field_name)
            r = results.runs.(field_name);
            parts = strsplit(metric_path, '.');
            val = r;
            for p = 1:length(parts)
                if isfield(val, parts{p}), val = val.(parts{p});
                else, val = NaN; break; end
            end
            values(end+1) = val;
        end
    end
    if isempty(values), avg = NaN; sd = NaN;
    else, avg = mean(values); sd = std(values); end
end

function [x_sorted, cdf_values] = manual_cdf(data)
    data = data(:);
    data = data(~isnan(data));
    n = length(data);
    x_sorted = sort(data);
    cdf_values = (1:n)' / n;
end