%% analyze_thold_results.m
% T_hold Trade-off 실험 결과 분석 및 시각화
%
% 실행 전 run_thold_experiments.m 완료 필요

clear; clc;

%% ═══════════════════════════════════════════════════════════════════
%  데이터 로드
%  ═══════════════════════════════════════════════════════════════════

results_dir = 'results';
figures_dir = fullfile(results_dir, 'figures');
if ~exist(figures_dir, 'dir')
    mkdir(figures_dir);
end

% CSV 로드
phase1 = readtable(fullfile(results_dir, 'summary', 'phase1_baseline.csv'));
phase2 = readtable(fullfile(results_dir, 'summary', 'phase2_thold_sweep.csv'));
phase3 = readtable(fullfile(results_dir, 'summary', 'phase3_rho_thold.csv'));

fprintf('데이터 로드 완료\n');
fprintf('  Phase 1: %d rows\n', height(phase1));
fprintf('  Phase 2: %d rows\n', height(phase2));
fprintf('  Phase 3: %d rows\n', height(phase3));

%% ═══════════════════════════════════════════════════════════════════
%  Figure 1: Phase 2 - T_hold 스윕 (Mean Delay)
%  ═══════════════════════════════════════════════════════════════════

figure('Position', [100 100 800 500]);

sta_list = [20, 30, 50, 70];
thold_list = [0, 5, 10, 20, 50];
colors = lines(4);
markers = {'o', 's', '^', 'd'};

hold on;
for i = 1:length(sta_list)
    sta = sta_list(i);
    idx = phase2.num_stas == sta;
    data = phase2(idx, :);
    data = sortrows(data, 'thold_ms');
    
    plot(data.thold_ms, data.delay_mean_ms, ...
        '-', 'Color', colors(i,:), 'LineWidth', 2, ...
        'Marker', markers{i}, 'MarkerSize', 8, 'MarkerFaceColor', colors(i,:));
end
hold off;

xlabel('T_{hold} (ms)', 'FontSize', 12);
ylabel('Mean Delay (ms)', 'FontSize', 12);
title('T_{hold} 값에 따른 평균 지연 변화', 'FontSize', 14);
legend(arrayfun(@(x) sprintf('STA=%d', x), sta_list, 'UniformOutput', false), ...
    'Location', 'best');
grid on;
xlim([-2, 52]);

saveas(gcf, fullfile(figures_dir, 'fig1_thold_sweep_delay.png'));
fprintf('Figure 1 저장: fig1_thold_sweep_delay.png\n');

%% ═══════════════════════════════════════════════════════════════════
%  Figure 2: Phase 2 - T_hold 스윕 (Hit Rate)
%  ═══════════════════════════════════════════════════════════════════

figure('Position', [100 100 800 500]);

hold on;
for i = 1:length(sta_list)
    sta = sta_list(i);
    idx = phase2.num_stas == sta;
    data = phase2(idx, :);
    data = sortrows(data, 'thold_ms');
    
    % T_hold=0은 Hit Rate 없음
    valid_idx = data.thold_ms > 0;
    
    plot(data.thold_ms(valid_idx), data.thold_hit_rate(valid_idx) * 100, ...
        '-', 'Color', colors(i,:), 'LineWidth', 2, ...
        'Marker', markers{i}, 'MarkerSize', 8, 'MarkerFaceColor', colors(i,:));
end
hold off;

xlabel('T_{hold} (ms)', 'FontSize', 12);
ylabel('Hit Rate (%)', 'FontSize', 12);
title('T_{hold} 값에 따른 Hit Rate 변화', 'FontSize', 14);
legend(arrayfun(@(x) sprintf('STA=%d', x), sta_list, 'UniformOutput', false), ...
    'Location', 'best');
grid on;
xlim([3, 52]);
ylim([0, 100]);

saveas(gcf, fullfile(figures_dir, 'fig2_thold_sweep_hitrate.png'));
fprintf('Figure 2 저장: fig2_thold_sweep_hitrate.png\n');

%% ═══════════════════════════════════════════════════════════════════
%  Figure 3: Phase 2 - 지연 개선율
%  ═══════════════════════════════════════════════════════════════════

figure('Position', [100 100 800 500]);

hold on;
for i = 1:length(sta_list)
    sta = sta_list(i);
    idx = phase2.num_stas == sta;
    data = phase2(idx, :);
    data = sortrows(data, 'thold_ms');
    
    % 베이스라인 (T_hold=0) 대비 개선율
    baseline_delay = data.delay_mean_ms(data.thold_ms == 0);
    improvement = (baseline_delay - data.delay_mean_ms) / baseline_delay * 100;
    
    plot(data.thold_ms, improvement, ...
        '-', 'Color', colors(i,:), 'LineWidth', 2, ...
        'Marker', markers{i}, 'MarkerSize', 8, 'MarkerFaceColor', colors(i,:));
end
hold off;

xlabel('T_{hold} (ms)', 'FontSize', 12);
ylabel('지연 개선율 (%)', 'FontSize', 12);
title('T_{hold} 값에 따른 지연 개선율 (T_{hold}=0 대비)', 'FontSize', 14);
legend(arrayfun(@(x) sprintf('STA=%d', x), sta_list, 'UniformOutput', false), ...
    'Location', 'best');
grid on;
xlim([-2, 52]);
yline(0, '--k', 'LineWidth', 1);

saveas(gcf, fullfile(figures_dir, 'fig3_thold_sweep_improvement.png'));
fprintf('Figure 3 저장: fig3_thold_sweep_improvement.png\n');

%% ═══════════════════════════════════════════════════════════════════
%  Figure 4: Phase 3 - rho × T_hold 히트맵 (STA=20)
%  ═══════════════════════════════════════════════════════════════════

figure('Position', [100 100 700 500]);

sta = 20;
idx = phase3.num_stas == sta;
data = phase3(idx, :);

rho_list = unique(data.rho);
thold_list = unique(data.thold_ms);

% 히트맵 데이터 생성
heatmap_data = zeros(length(rho_list), length(thold_list));
for i = 1:length(rho_list)
    for j = 1:length(thold_list)
        row_idx = data.rho == rho_list(i) & data.thold_ms == thold_list(j);
        if any(row_idx)
            heatmap_data(i, j) = data.delay_mean_ms(row_idx);
        end
    end
end

% 개선율 계산 (T_hold=0 대비)
baseline = heatmap_data(:, 1);  % T_hold=0
improvement_matrix = (baseline - heatmap_data) ./ baseline * 100;

imagesc(improvement_matrix);
colormap(redblue_colormap());
colorbar;
caxis([-30 30]);

set(gca, 'XTick', 1:length(thold_list), 'XTickLabel', thold_list);
set(gca, 'YTick', 1:length(rho_list), 'YTickLabel', rho_list);
xlabel('T_{hold} (ms)', 'FontSize', 12);
ylabel('\rho', 'FontSize', 12);
title(sprintf('지연 개선율 히트맵 (STA=%d)', sta), 'FontSize', 14);

% 값 표시
for i = 1:length(rho_list)
    for j = 1:length(thold_list)
        val = improvement_matrix(i, j);
        if abs(val) > 15
            txt_color = 'w';
        else
            txt_color = 'k';
        end
        text(j, i, sprintf('%.1f%%', val), ...
            'HorizontalAlignment', 'center', 'Color', txt_color, 'FontSize', 10);
    end
end

saveas(gcf, fullfile(figures_dir, 'fig4_rho_thold_heatmap_sta20.png'));
fprintf('Figure 4 저장: fig4_rho_thold_heatmap_sta20.png\n');

%% ═══════════════════════════════════════════════════════════════════
%  Figure 5: Phase 3 - rho × T_hold 히트맵 (STA=50)
%  ═══════════════════════════════════════════════════════════════════

figure('Position', [100 100 700 500]);

sta = 50;
idx = phase3.num_stas == sta;
data = phase3(idx, :);

% 히트맵 데이터 생성
heatmap_data = zeros(length(rho_list), length(thold_list));
for i = 1:length(rho_list)
    for j = 1:length(thold_list)
        row_idx = data.rho == rho_list(i) & data.thold_ms == thold_list(j);
        if any(row_idx)
            heatmap_data(i, j) = data.delay_mean_ms(row_idx);
        end
    end
end

% 개선율 계산
baseline = heatmap_data(:, 1);
improvement_matrix = (baseline - heatmap_data) ./ baseline * 100;

imagesc(improvement_matrix);
colormap(redblue_colormap());
colorbar;
caxis([-30 30]);

set(gca, 'XTick', 1:length(thold_list), 'XTickLabel', thold_list);
set(gca, 'YTick', 1:length(rho_list), 'YTickLabel', rho_list);
xlabel('T_{hold} (ms)', 'FontSize', 12);
ylabel('\rho', 'FontSize', 12);
title(sprintf('지연 개선율 히트맵 (STA=%d)', sta), 'FontSize', 14);

% 값 표시
for i = 1:length(rho_list)
    for j = 1:length(thold_list)
        val = improvement_matrix(i, j);
        if abs(val) > 15
            txt_color = 'w';
        else
            txt_color = 'k';
        end
        text(j, i, sprintf('%.1f%%', val), ...
            'HorizontalAlignment', 'center', 'Color', txt_color, 'FontSize', 10);
    end
end

saveas(gcf, fullfile(figures_dir, 'fig5_rho_thold_heatmap_sta50.png'));
fprintf('Figure 5 저장: fig5_rho_thold_heatmap_sta50.png\n');

%% ═══════════════════════════════════════════════════════════════════
%  Figure 6: Phase 3 - Hit Rate vs rho
%  ═══════════════════════════════════════════════════════════════════

figure('Position', [100 100 800 500]);

thold_subset = [10, 20, 50];
colors_thold = lines(length(thold_subset));
line_styles = {'-', '--', ':'};

subplot(1, 2, 1);
hold on;
sta = 20;
idx = phase3.num_stas == sta;
data = phase3(idx, :);
for i = 1:length(thold_subset)
    th = thold_subset(i);
    th_idx = data.thold_ms == th;
    th_data = sortrows(data(th_idx, :), 'rho');
    plot(th_data.rho, th_data.thold_hit_rate * 100, ...
        line_styles{i}, 'Color', colors_thold(i,:), 'LineWidth', 2, ...
        'Marker', 'o', 'MarkerSize', 6, 'MarkerFaceColor', colors_thold(i,:));
end
hold off;
xlabel('\rho', 'FontSize', 11);
ylabel('Hit Rate (%)', 'FontSize', 11);
title(sprintf('STA=%d', sta), 'FontSize', 12);
legend(arrayfun(@(x) sprintf('T_{hold}=%dms', x), thold_subset, 'UniformOutput', false), ...
    'Location', 'best');
grid on;
ylim([0, 100]);

subplot(1, 2, 2);
hold on;
sta = 50;
idx = phase3.num_stas == sta;
data = phase3(idx, :);
for i = 1:length(thold_subset)
    th = thold_subset(i);
    th_idx = data.thold_ms == th;
    th_data = sortrows(data(th_idx, :), 'rho');
    plot(th_data.rho, th_data.thold_hit_rate * 100, ...
        line_styles{i}, 'Color', colors_thold(i,:), 'LineWidth', 2, ...
        'Marker', 'o', 'MarkerSize', 6, 'MarkerFaceColor', colors_thold(i,:));
end
hold off;
xlabel('\rho', 'FontSize', 11);
ylabel('Hit Rate (%)', 'FontSize', 11);
title(sprintf('STA=%d', sta), 'FontSize', 12);
legend(arrayfun(@(x) sprintf('T_{hold}=%dms', x), thold_subset, 'UniformOutput', false), ...
    'Location', 'best');
grid on;
ylim([0, 100]);

sgtitle('Hit Rate vs \rho (T_{hold} 값별)', 'FontSize', 14);

saveas(gcf, fullfile(figures_dir, 'fig6_hitrate_vs_rho.png'));
fprintf('Figure 6 저장: fig6_hitrate_vs_rho.png\n');

%% ═══════════════════════════════════════════════════════════════════
%  Figure 7: Phase 3 - Collision Rate 비교
%  ═══════════════════════════════════════════════════════════════════

figure('Position', [100 100 800 500]);

subplot(1, 2, 1);
hold on;
sta = 20;
idx = phase3.num_stas == sta;
data = phase3(idx, :);

thold_list_plot = [0, 10, 20, 50];
for i = 1:length(thold_list_plot)
    th = thold_list_plot(i);
    th_idx = data.thold_ms == th;
    th_data = sortrows(data(th_idx, :), 'rho');
    
    if th == 0
        style = '-k';
        lw = 2;
    else
        style = '-';
        lw = 1.5;
    end
    
    plot(th_data.rho, th_data.uora_collision_rate * 100, style, ...
        'LineWidth', lw, 'Marker', 'o', 'MarkerSize', 5);
end
hold off;
xlabel('\rho', 'FontSize', 11);
ylabel('Collision Rate (%)', 'FontSize', 11);
title(sprintf('STA=%d', sta), 'FontSize', 12);
legend(arrayfun(@(x) sprintf('T_{hold}=%dms', x), thold_list_plot, 'UniformOutput', false), ...
    'Location', 'best');
grid on;

subplot(1, 2, 2);
hold on;
sta = 50;
idx = phase3.num_stas == sta;
data = phase3(idx, :);

for i = 1:length(thold_list_plot)
    th = thold_list_plot(i);
    th_idx = data.thold_ms == th;
    th_data = sortrows(data(th_idx, :), 'rho');
    
    if th == 0
        style = '-k';
        lw = 2;
    else
        style = '-';
        lw = 1.5;
    end
    
    plot(th_data.rho, th_data.uora_collision_rate * 100, style, ...
        'LineWidth', lw, 'Marker', 'o', 'MarkerSize', 5);
end
hold off;
xlabel('\rho', 'FontSize', 11);
ylabel('Collision Rate (%)', 'FontSize', 11);
title(sprintf('STA=%d', sta), 'FontSize', 12);
legend(arrayfun(@(x) sprintf('T_{hold}=%dms', x), thold_list_plot, 'UniformOutput', false), ...
    'Location', 'best');
grid on;

sgtitle('Collision Rate vs \rho (T_{hold} 값별)', 'FontSize', 14);

saveas(gcf, fullfile(figures_dir, 'fig7_collision_vs_rho.png'));
fprintf('Figure 7 저장: fig7_collision_vs_rho.png\n');

%% ═══════════════════════════════════════════════════════════════════
%  Figure 8: Trade-off 산점도 (Wasted vs Saved)
%  ═══════════════════════════════════════════════════════════════════

figure('Position', [100 100 800 600]);

% Phase 3 데이터에서 T_hold > 0인 것만
data = phase3(phase3.thold_ms > 0, :);

% Saved Delay 계산 (같은 STA/rho에서 T_hold=0 대비)
saved_delay = zeros(height(data), 1);
for i = 1:height(data)
    sta = data.num_stas(i);
    rho = data.rho(i);
    baseline_idx = phase3.num_stas == sta & phase3.rho == rho & phase3.thold_ms == 0;
    if any(baseline_idx)
        baseline_delay = phase3.delay_mean_ms(baseline_idx);
        saved_delay(i) = baseline_delay - data.delay_mean_ms(i);
    end
end
data.saved_delay_ms = saved_delay;

% Wasted Time 계산 (T_hold 만료로 낭비된 시간)
data.wasted_per_pkt_ms = data.thold_wasted_ms ./ max(data.packets_completed, 1);

% rho별 색상
rho_vals = unique(data.rho);
colors_rho = parula(length(rho_vals));

hold on;
for i = 1:length(rho_vals)
    rho = rho_vals(i);
    idx = data.rho == rho;
    scatter(data.wasted_per_pkt_ms(idx), data.saved_delay_ms(idx), 80, ...
        'filled', 'MarkerFaceColor', colors_rho(i,:), ...
        'MarkerEdgeColor', 'k', 'LineWidth', 0.5);
end

% 손익분기선
max_val = max([max(data.wasted_per_pkt_ms), max(data.saved_delay_ms)]) * 1.1;
plot([0, max_val], [0, max_val], '--k', 'LineWidth', 1.5);
text(max_val * 0.7, max_val * 0.6, '손익분기선', 'FontSize', 10);

hold off;

xlabel('Wasted Time per Packet (ms)', 'FontSize', 12);
ylabel('Saved Delay (ms)', 'FontSize', 12);
title('T_{hold} Trade-off: 비용 vs 이득', 'FontSize', 14);
legend(arrayfun(@(x) sprintf('\\rho=%.1f', x), rho_vals, 'UniformOutput', false), ...
    'Location', 'best');
grid on;

% 영역 표시
xline(0, '-k');
yline(0, '-k');
text(max_val * 0.6, -max_val * 0.1, '손해 영역', 'FontSize', 10, 'Color', 'r');
text(max_val * 0.1, max_val * 0.8, '이득 영역', 'FontSize', 10, 'Color', 'b');

saveas(gcf, fullfile(figures_dir, 'fig8_tradeoff_scatter.png'));
fprintf('Figure 8 저장: fig8_tradeoff_scatter.png\n');

%% ═══════════════════════════════════════════════════════════════════
%  결과 요약 출력
%  ═══════════════════════════════════════════════════════════════════

fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════╗\n');
fprintf('║                    결과 요약                                 ║\n');
fprintf('╚══════════════════════════════════════════════════════════════╝\n\n');

% Phase 1 베이스라인 요약
fprintf('■ Phase 1: 베이스라인 (T_hold OFF)\n');
fprintf('  ┌──────┬───────┬────────────┬──────────────┬─────────────┐\n');
fprintf('  │ STA  │  rho  │ Delay(ms)  │ Collision(%%) │   Jain      │\n');
fprintf('  ├──────┼───────┼────────────┼──────────────┼─────────────┤\n');
for i = 1:height(phase1)
    fprintf('  │ %3d  │  %.1f  │   %6.2f   │    %5.1f     │   %.4f    │\n', ...
        phase1.num_stas(i), phase1.rho(i), phase1.delay_mean_ms(i), ...
        phase1.uora_collision_rate(i)*100, phase1.jain_index(i));
end
fprintf('  └──────┴───────┴────────────┴──────────────┴─────────────┘\n\n');

% Phase 2 최적 T_hold
fprintf('■ Phase 2: STA별 최적 T_hold (rho=0.5)\n');
for sta = [20, 30, 50, 70]
    idx = phase2.num_stas == sta;
    data = phase2(idx, :);
    [min_delay, min_idx] = min(data.delay_mean_ms);
    best_thold = data.thold_ms(min_idx);
    baseline = data.delay_mean_ms(data.thold_ms == 0);
    improvement = (baseline - min_delay) / baseline * 100;
    fprintf('  STA=%d: 최적 T_hold=%dms (지연 %.1fms → %.1fms, 개선율 %.1f%%)\n', ...
        sta, best_thold, baseline, min_delay, improvement);
end
fprintf('\n');

% Phase 3 Trade-off 영역
fprintf('■ Phase 3: Trade-off 영역 분석\n');
for sta = [20, 50]
    fprintf('  STA=%d:\n', sta);
    idx = phase3.num_stas == sta;
    data = phase3(idx, :);
    
    for rho = [0.2, 0.4, 0.6, 0.8]
        rho_idx = data.rho == rho;
        rho_data = data(rho_idx, :);
        baseline = rho_data.delay_mean_ms(rho_data.thold_ms == 0);
        
        best_idx = find(rho_data.delay_mean_ms == min(rho_data.delay_mean_ms), 1);
        best_thold = rho_data.thold_ms(best_idx);
        best_delay = rho_data.delay_mean_ms(best_idx);
        improvement = (baseline - best_delay) / baseline * 100;
        
        if improvement > 5
            status = '✅ 효과적';
        elseif improvement > -5
            status = '➖ 미미';
        else
            status = '❌ 손해';
        end
        
        fprintf('    rho=%.1f: %s (최적 T_hold=%dms, 개선율 %.1f%%)\n', ...
            rho, status, best_thold, improvement);
    end
end

fprintf('\n분석 완료. 그래프는 %s 폴더에 저장됨\n', figures_dir);

%% ═══════════════════════════════════════════════════════════════════
%  보조 함수: Red-Blue 컬러맵
%  ═══════════════════════════════════════════════════════════════════

function cmap = redblue_colormap()
    n = 256;
    r = [linspace(0.2, 1, n/2), ones(1, n/2)];
    g = [linspace(0.2, 1, n/2), linspace(1, 0.2, n/2)];
    b = [ones(1, n/2), linspace(1, 0.2, n/2)];
    cmap = [r', g', b'];
end