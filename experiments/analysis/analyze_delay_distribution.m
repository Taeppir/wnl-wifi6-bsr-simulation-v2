%% analyze_delay_boxplot.m
% Boxplot 스타일 지연 분포 시각화 (Toolbox 없이 직접 구현)
% 
% Boxplot: 박스=Q1~Q3, 중간선=P50, 수염=P10~P90

clear; clc;
fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════════╗\n');
fprintf('║            지연 분포 Boxplot 분석                                 ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════╝\n\n');

%% 데이터 로드
m0m1_file = 'results/main_m0_m1_final/results.mat';
m2_file = 'results/main_m2_final/results.mat';

load(m0m1_file, 'results'); results_m0m1 = results;
load(m2_file, 'results'); results_m2 = results;
fprintf('[데이터 로드 완료]\n\n');

%% 설정
scenarios = {'A', 'B', 'C'};
scenario_desc = {'VoIP-like', 'Video-like', 'IoT-like'};
thold_values = [30, 50, 70];
num_seeds = 5;

% 색상
colors.Baseline = [0.5 0.5 0.5];
colors.M0 = [0.2 0.4 0.8];
colors.M1 = [0.9 0.6 0.1];
colors.M2 = [0.2 0.7 0.3];

output_dir = 'results/figures_delay';
if ~exist(output_dir, 'dir'), mkdir(output_dir); end

%% Figure 1: 시나리오별 통합 Boxplot
figure('Name', 'Delay Boxplot Combined', 'Position', [50 200 1600 500]);

for sc_idx = 1:3
    sc = scenarios{sc_idx};
    subplot(1, 3, sc_idx);
    hold on;
    
    % 데이터 수집 및 boxplot 그리기
    x_pos = 0;
    x_ticks = [];
    x_labels = {};
    
    % Baseline
    x_pos = x_pos + 1;
    delays = get_all_delays(results_m0m1, sc, 0, 'Baseline', num_seeds);
    draw_boxplot(x_pos, delays, colors.Baseline, 0.6);
    x_ticks(end+1) = x_pos;
    x_labels{end+1} = 'Base';
    base_median = calc_median(delays);
    
    % 구분선
    xline(x_pos + 0.5, '-', 'Color', [0.7 0.7 0.7], 'LineWidth', 1);
    
    % SERM-∞ (T30, T50, T70)
    for th = thold_values
        x_pos = x_pos + 1;
        delays = get_all_delays(results_m0m1, sc, th, 'M0', num_seeds);
        draw_boxplot(x_pos, delays, colors.M0, 0.6);
        x_ticks(end+1) = x_pos;
        x_labels{end+1} = sprintf('%d', th);
    end
    
    % 구분선
    xline(x_pos + 0.5, '-', 'Color', [0.7 0.7 0.7], 'LineWidth', 1);
    
    % SERM-5 (T30, T50, T70)
    for th = thold_values
        x_pos = x_pos + 1;
        delays = get_all_delays(results_m0m1, sc, th, 'M1(5)', num_seeds);
        draw_boxplot(x_pos, delays, colors.M1, 0.6);
        x_ticks(end+1) = x_pos;
        x_labels{end+1} = sprintf('%d', th);
    end
    
    % 구분선
    xline(x_pos + 0.5, '-', 'Color', [0.7 0.7 0.7], 'LineWidth', 1);
    
    % SERM-P (T30, T50, T70)
    for th = thold_values
        x_pos = x_pos + 1;
        delays = get_all_delays(results_m2, sc, th, 'M2', num_seeds);
        draw_boxplot(x_pos, delays, colors.M2, 0.6);
        x_ticks(end+1) = x_pos;
        x_labels{end+1} = sprintf('%d', th);
    end
    
    hold off;
    
    set(gca, 'XTick', x_ticks, 'XTickLabel', x_labels, 'FontSize', 8);
    xlim([0.5, x_pos + 0.5]);
    ylim([0, 250]);  % y축 고정
    xlabel('T_{ret} (ms)', 'FontSize', 10);
    ylabel('Delay (ms)', 'FontSize', 10);
    title(sprintf('시나리오 %s', sc), 'FontSize', 12);
    
    % 그룹명 추가
    yl = ylim;
    text(1, yl(1) - (yl(2)-yl(1))*0.10, 'Baseline', 'HorizontalAlignment', 'center', ...
        'FontSize', 9, 'FontWeight', 'bold', 'Color', colors.Baseline);
    text(3, yl(1) - (yl(2)-yl(1))*0.10, 'SERM-\infty', 'HorizontalAlignment', 'center', ...
        'FontSize', 9, 'FontWeight', 'bold', 'Color', colors.M0);
    text(6, yl(1) - (yl(2)-yl(1))*0.10, 'SERM-5', 'HorizontalAlignment', 'center', ...
        'FontSize', 9, 'FontWeight', 'bold', 'Color', colors.M1);
    text(9, yl(1) - (yl(2)-yl(1))*0.10, 'SERM-P', 'HorizontalAlignment', 'center', ...
        'FontSize', 9, 'FontWeight', 'bold', 'Color', colors.M2);
    
    set(gca, 'YGrid', 'on', 'XGrid', 'off');  % y축 그리드만
end

%% Figure 2: CDF 비교
figure('Name', 'Delay CDF', 'Position', [100 100 1600 450]);

% 기본색 정의
base_M0 = [0.2 0.4 0.8];   % 파랑
base_M1 = [0.9 0.5 0.1];   % 주황
base_M2 = [0.2 0.6 0.3];   % 초록

% 밝기 조절 (T30=진하게, T50=중간, T70=연하게)
brighten = @(c, f) c + (1-c) * f;

colors_M0 = [base_M0;
             brighten(base_M0, 0.2);
             brighten(base_M0, 0.4)];

colors_M1 = [base_M1;
             brighten(base_M1, 0.2);
             brighten(base_M1, 0.4)];

colors_M2 = [base_M2;
             brighten(base_M2, 0.2);
             brighten(base_M2, 0.4)];

for sc_idx = 1:3
    sc = scenarios{sc_idx};
    subplot(1, 3, sc_idx);
    hold on;
    
    % Baseline (검은색)
    base_d = get_all_delays(results_m0m1, sc, 0, 'Baseline', num_seeds);
    [x_base, f_base] = calc_cdf(base_d);
    plot(x_base, f_base, 'Color', [0.2 0.2 0.2], 'LineStyle', '-', 'LineWidth', 1.5);
    
    % SERM-∞ - 파란색 계열
    for th_idx = 1:3
        th = thold_values(th_idx);
        d = get_all_delays(results_m0m1, sc, th, 'M0', num_seeds);
        [x_cdf, f_cdf] = calc_cdf(d);
        plot(x_cdf, f_cdf, 'Color', colors_M0(th_idx,:), 'LineStyle', '-', 'LineWidth', 1.5);
    end
    
    % SERM-5 - 주황색 계열
    for th_idx = 1:3
        th = thold_values(th_idx);
        d = get_all_delays(results_m0m1, sc, th, 'M1(5)', num_seeds);
        [x_cdf, f_cdf] = calc_cdf(d);
        plot(x_cdf, f_cdf, 'Color', colors_M1(th_idx,:), 'LineStyle', '-', 'LineWidth', 1.5);
    end
    
    % SERM-P - 초록색 계열
    for th_idx = 1:3
        th = thold_values(th_idx);
        d = get_all_delays(results_m2, sc, th, 'M2', num_seeds);
        [x_cdf, f_cdf] = calc_cdf(d);
        plot(x_cdf, f_cdf, 'Color', colors_M2(th_idx,:), 'LineStyle', '-', 'LineWidth', 1.5);
    end
    
    hold off;
    
    xlabel('Delay (ms)', 'FontSize', 10);
    ylabel('CDF', 'FontSize', 10);
    title(sprintf('시나리오 %s', sc), 'FontSize', 12);
    xlim([0 200]);
    ylim([0 1]);
    set(gca, 'YGrid', 'on', 'XGrid', 'on');
    
    % 범례 (첫 번째 subplot에만)
    if sc_idx == 1
        legend({'Baseline', ...
                'SERM-\infty T30', 'SERM-\infty T50', 'SERM-\infty T70', ...
                'SERM-5 T30', 'SERM-5 T50', 'SERM-5 T70', ...
                'SERM-P T30', 'SERM-P T50', 'SERM-P T70'}, ...
                'Location', 'southeast', 'FontSize', 7);
    end
end

%% Figure 3: Mean Delay (Error bar = P10~P90)
figure('Name', 'Mean Delay Errorbar', 'Position', [100 100 1500 400]);

for sc_idx = 1:3
    sc = scenarios{sc_idx};
    subplot(1, 3, sc_idx);
    hold on;
    
    % Baseline 데이터
    base_d = get_all_delays(results_m0m1, sc, 0, 'Baseline', num_seeds);
    base_mean = mean(base_d);
    base_p10 = calc_quantile(base_d, 0.10);
    base_p90 = calc_quantile(base_d, 0.90);
    
    % SERM-∞, SERM-5, SERM-P 데이터 수집
    mean_m0 = zeros(1, 3); p10_m0 = zeros(1, 3); p90_m0 = zeros(1, 3);
    mean_m1 = zeros(1, 3); p10_m1 = zeros(1, 3); p90_m1 = zeros(1, 3);
    mean_m2 = zeros(1, 3); p10_m2 = zeros(1, 3); p90_m2 = zeros(1, 3);
    
    for th_idx = 1:3
        th = thold_values(th_idx);
        
        d = get_all_delays(results_m0m1, sc, th, 'M0', num_seeds);
        mean_m0(th_idx) = mean(d);
        p10_m0(th_idx) = calc_quantile(d, 0.10);
        p90_m0(th_idx) = calc_quantile(d, 0.90);
        
        d = get_all_delays(results_m0m1, sc, th, 'M1(5)', num_seeds);
        mean_m1(th_idx) = mean(d);
        p10_m1(th_idx) = calc_quantile(d, 0.10);
        p90_m1(th_idx) = calc_quantile(d, 0.90);
        
        d = get_all_delays(results_m2, sc, th, 'M2', num_seeds);
        mean_m2(th_idx) = mean(d);
        p10_m2(th_idx) = calc_quantile(d, 0.10);
        p90_m2(th_idx) = calc_quantile(d, 0.90);
    end
    
    % 오프셋
    offset = 2;
    
    % Baseline (각 T_ret 위치에 동일하게 표시)
    base_means = repmat(base_mean, 1, 3);
    base_p10s = repmat(base_p10, 1, 3);
    base_p90s = repmat(base_p90, 1, 3);
    
    errorbar(thold_values - 1.5*offset, base_means, base_means - base_p10s, base_p90s - base_means, 'd', ...
        'Color', colors.Baseline, 'LineWidth', 1.5, 'MarkerSize', 8, 'MarkerFaceColor', colors.Baseline, 'CapSize', 5);
    errorbar(thold_values - 0.5*offset, mean_m0, mean_m0 - p10_m0, p90_m0 - mean_m0, 'o', ...
        'Color', colors.M0, 'LineWidth', 1.5, 'MarkerSize', 8, 'MarkerFaceColor', colors.M0, 'CapSize', 5);
    errorbar(thold_values + 0.5*offset, mean_m1, mean_m1 - p10_m1, p90_m1 - mean_m1, 's', ...
        'Color', colors.M1, 'LineWidth', 1.5, 'MarkerSize', 8, 'MarkerFaceColor', colors.M1, 'CapSize', 5);
    errorbar(thold_values + 1.5*offset, mean_m2, mean_m2 - p10_m2, p90_m2 - mean_m2, '^', ...
        'Color', colors.M2, 'LineWidth', 1.5, 'MarkerSize', 8, 'MarkerFaceColor', colors.M2, 'CapSize', 5);
    
    hold off;
    
    xlabel('T_{ret} (ms)', 'FontSize', 11);
    ylabel('Mean Delay (ms)', 'FontSize', 11);
    title(sprintf('시나리오 %s', sc), 'FontSize', 12);
    xlim([22 78]);
    set(gca, 'XTick', thold_values);
    grid on;
    
    if sc_idx == 3
        legend({'Baseline', 'SERM-\infty', 'SERM-5', 'SERM-P'}, 'Location', 'northeast', 'FontSize', 9);
    end
end

%% 저장 (PDF + PNG)
exportgraphics(figure(1), fullfile(output_dir, 'delay_boxplot_all.pdf'), 'ContentType', 'vector');
exportgraphics(figure(1), fullfile(output_dir, 'delay_boxplot_all.png'), 'Resolution', 300);
exportgraphics(figure(2), fullfile(output_dir, 'delay_cdf.pdf'), 'ContentType', 'vector');
exportgraphics(figure(2), fullfile(output_dir, 'delay_cdf.png'), 'Resolution', 300);
exportgraphics(figure(3), fullfile(output_dir, 'delay_mean_errorbar.pdf'), 'ContentType', 'vector');
exportgraphics(figure(3), fullfile(output_dir, 'delay_mean_errorbar.png'), 'Resolution', 300);

fprintf('\n[저장 완료]\n');
fprintf('  - %s/delay_boxplot_all.pdf / .png\n', output_dir);
fprintf('  - %s/delay_cdf.pdf / .png\n', output_dir);
fprintf('  - %s/delay_mean_errorbar.pdf / .png\n', output_dir);

%% 통계 출력
fprintf('\n');
fprintf('═══════════════════════════════════════════════════════════════════════════\n');
fprintf('                    지연 통계 요약 (평균 기준)\n');
fprintf('═══════════════════════════════════════════════════════════════════════════\n');

for sc_idx = 1:3
    sc = scenarios{sc_idx};
    fprintf('\n[시나리오 %s: %s]\n', sc, scenario_desc{sc_idx});
    
    base_d = get_all_delays(results_m0m1, sc, 0, 'Baseline', num_seeds);
    base_mean = mean(base_d);
    
    fprintf('  %-10s: 평균=%6.1fms, P10=%6.1fms, P90=%6.1fms\n', ...
        'Baseline', base_mean, calc_quantile(base_d, 0.10), calc_quantile(base_d, 0.90));
    
    methods_list = {'M0', 'M1(5)', 'M2'};
    method_names = {'SERM-∞', 'SERM-5', 'SERM-P'};
    
    for m_idx = 1:3
        method = methods_list{m_idx};
        fprintf('  %s:\n', method_names{m_idx});
        
        for th = thold_values
            if strcmp(method, 'M2')
                d = get_all_delays(results_m2, sc, th, method, num_seeds);
            else
                d = get_all_delays(results_m0m1, sc, th, method, num_seeds);
            end
            
            m = mean(d);
            improve = (base_mean - m) / base_mean * 100;
            fprintf('    T%d: 평균=%6.1fms (%.0f%% 개선), P10=%6.1f, P90=%6.1f\n', ...
                th, m, improve, calc_quantile(d, 0.10), calc_quantile(d, 0.90));
        end
    end
end

%% ═══════════════════════════════════════════════════════════════════════════
%  Helper Functions
%% ═══════════════════════════════════════════════════════════════════════════

function draw_boxplot(x, data, color, width)
    data = data(~isnan(data));
    if isempty(data)
        return;
    end
    
    % 통계량 계산
    p10 = calc_quantile(data, 0.10);
    q1 = calc_quantile(data, 0.25);
    q2 = calc_quantile(data, 0.50);  % median
    q3 = calc_quantile(data, 0.75);
    p90 = calc_quantile(data, 0.90);
    min_val = p10;
    max_val = p90;
    
    half_w = width / 2;
    
    % 박스 (Q1 ~ Q3)
    patch([x-half_w, x+half_w, x+half_w, x-half_w], ...
          [q1, q1, q3, q3], ...
          color, 'FaceAlpha', 0.5, 'EdgeColor', color, 'LineWidth', 1.5);
    
    % 중위값 선
    plot([x-half_w, x+half_w], [q2, q2], 'k-', 'LineWidth', 2);
    
    % 수염 (P10 ~ Q1, Q3 ~ P90)
    plot([x, x], [min_val, q1], 'k-', 'LineWidth', 1);
    plot([x, x], [q3, max_val], 'k-', 'LineWidth', 1);
    
    % 수염 끝 가로선
    cap_w = width / 4;
    plot([x-cap_w, x+cap_w], [min_val, min_val], 'k-', 'LineWidth', 1);
    plot([x-cap_w, x+cap_w], [max_val, max_val], 'k-', 'LineWidth', 1);
end

function delays = get_all_delays(results, scenario, thold_ms, method, num_seeds)
    delays = [];
    
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
            if isfield(r, 'delay') && isfield(r.delay, 'all_ms')
                delays = [delays; r.delay.all_ms(:)];
            end
        end
    end
end

function m = calc_median(data)
    data = data(~isnan(data));
    sorted_d = sort(data);
    n = length(sorted_d);
    if mod(n, 2) == 0
        m = (sorted_d(n/2) + sorted_d(n/2 + 1)) / 2;
    else
        m = sorted_d((n + 1) / 2);
    end
end

function q = calc_quantile(data, p)
    data = data(~isnan(data));
    sorted_d = sort(data);
    n = length(sorted_d);
    idx = max(1, round(p * n));
    q = sorted_d(idx);
end

function [x, f] = calc_cdf(data)
    data = data(~isnan(data));
    x = sort(data);
    n = length(x);
    f = (1:n)' / n;
end