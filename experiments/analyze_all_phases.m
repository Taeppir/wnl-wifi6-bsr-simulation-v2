%% analyze_all_phases.m
% Phase 1, 2, 3 결과 종합 분석 (num_runs=3 반복 실험 통계 처리)
%
% 통계: 같은 조건의 반복 실험에서 평균 ± 표준편차

clear; clc;
addpath(genpath(pwd));

%% 데이터 로드
results_dir = 'results/summary';
figures_dir = 'results/figures';
if ~exist(figures_dir, 'dir'), mkdir(figures_dir); end

try
    phase1_raw = readtable(fullfile(results_dir, 'phase1_baseline.csv'));
    phase2_raw = readtable(fullfile(results_dir, 'phase2_thold_sweep.csv'));
    phase3_raw = readtable(fullfile(results_dir, 'phase3_rho_sweep.csv'));
    fprintf('데이터 로드 완료: Phase1=%d, Phase2=%d, Phase3=%d rows\n', ...
        height(phase1_raw), height(phase2_raw), height(phase3_raw));
catch ME
    fprintf('데이터 로드 실패: %s\n', ME.message);
    return;
end

%% 통계 처리 (조건별 평균/표준편차)
fprintf('통계 처리 중...\n');

% Phase 1: STA × rho 조건별
[phase1, p1_groups] = calc_group_stats(phase1_raw, {'num_stas', 'rho'});

% Phase 2: STA × T_hold 조건별  
[phase2, p2_groups] = calc_group_stats(phase2_raw, {'num_stas', 'thold_ms'});

% Phase 3: STA × rho 조건별
[phase3, p3_groups] = calc_group_stats(phase3_raw, {'num_stas', 'rho'});

fprintf('통계 처리 완료: Phase1=%d, Phase2=%d, Phase3=%d 조건\n\n', ...
    height(phase1), height(phase2), height(phase3));

%% ═══════════════════════════════════════════════════════════════════
%  1. Phase 1: Baseline 결과
%  ═══════════════════════════════════════════════════════════════════

fprintf('╔══════════════════════════════════════════════════════════════╗\n');
fprintf('║  1. Baseline 결과 (Phase 1, T_hold=OFF)                      ║\n');
fprintf('╚══════════════════════════════════════════════════════════════╝\n\n');

fprintf('%-6s | %-6s | %15s | %15s | %15s | %12s\n', ...
    'STA', 'rho', 'Delay(ms)', 'Collision%', 'Complete%', 'Jain');
fprintf('%s\n', repmat('-', 1, 85));

for i = 1:height(phase1)
    fprintf('%-6d | %-6.1f | %6.1f ± %5.1f | %6.1f ± %5.1f | %6.1f ± %4.1f | %.3f ± %.3f\n', ...
        phase1.num_stas(i), phase1.rho(i), ...
        phase1.delay_mean_ms_mean(i), phase1.delay_mean_ms_std(i), ...
        phase1.uora_collision_rate_mean(i)*100, phase1.uora_collision_rate_std(i)*100, ...
        phase1.completion_rate_mean(i)*100, phase1.completion_rate_std(i)*100, ...
        phase1.jain_index_mean(i), phase1.jain_index_std(i));
end

%% ═══════════════════════════════════════════════════════════════════
%  2. Phase 2: T_hold 값별 성능 비교
%  ═══════════════════════════════════════════════════════════════════

fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════╗\n');
fprintf('║  2. T_hold 값별 성능 비교 (Phase 2, rho=0.5)                 ║\n');
fprintf('╚══════════════════════════════════════════════════════════════╝\n\n');

sta_list = unique(phase2.num_stas);
thold_list = unique(phase2.thold_ms);

% Baseline (rho=0.5)
baseline_rho05 = phase1(abs(phase1.rho - 0.5) < 0.01, :);

fprintf('%-6s | %-8s | %15s | %10s | %15s | %12s\n', ...
    'STA', 'T_hold', 'Delay(ms)', 'Improve%', 'Complete%', 'HitRate%');
fprintf('%s\n', repmat('-', 1, 85));

for si = 1:length(sta_list)
    sta = sta_list(si);
    
    % Baseline
    base_idx = baseline_rho05.num_stas == sta;
    if ~any(base_idx), continue; end
    base_delay = baseline_rho05.delay_mean_ms_mean(base_idx);
    base_complete = baseline_rho05.completion_rate_mean(base_idx);
    
    fprintf('%-6d | %8s | %6.1f ± %5.1f | %10s | %6.1f ± %4.1f | %12s\n', ...
        sta, 'Baseline', base_delay, baseline_rho05.delay_mean_ms_std(base_idx), ...
        '-', base_complete*100, baseline_rho05.completion_rate_std(base_idx)*100, '-');
    
    for ti = 1:length(thold_list)
        thold = thold_list(ti);
        
        idx = phase2.num_stas == sta & phase2.thold_ms == thold;
        if ~any(idx), continue; end
        
        delay_m = phase2.delay_mean_ms_mean(idx);
        delay_s = phase2.delay_mean_ms_std(idx);
        complete_m = phase2.completion_rate_mean(idx);
        complete_s = phase2.completion_rate_std(idx);
        hit_rate_m = phase2.thold_hit_rate_mean(idx);
        hit_rate_s = phase2.thold_hit_rate_std(idx);
        
        improve = (base_delay - delay_m) / base_delay * 100;
        
        fprintf('%-6d | %6dms | %6.1f ± %5.1f | %+9.1f%% | %6.1f ± %4.1f | %5.1f ± %4.1f\n', ...
            sta, thold, delay_m, delay_s, improve, complete_m*100, complete_s*100, ...
            hit_rate_m*100, hit_rate_s*100);
    end
    fprintf('%s\n', repmat('-', 1, 85));
end

%% ═══════════════════════════════════════════════════════════════════
%  3. T_hold 상세 카운트 (Phase 2)
%  ═══════════════════════════════════════════════════════════════════

fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════╗\n');
fprintf('║  3. T_hold 상세 카운트 (Phase 2)                             ║\n');
fprintf('╚══════════════════════════════════════════════════════════════╝\n\n');

fprintf('%-6s | %-8s | %12s | %12s | %12s | %12s\n', ...
    'STA', 'T_hold', 'Activations', 'Hits', 'Expirations', 'Phantom');
fprintf('%s\n', repmat('-', 1, 75));

for i = 1:height(phase2)
    fprintf('%-6d | %6dms | %5.0f ± %4.0f | %5.0f ± %4.0f | %5.0f ± %4.0f | %6.0f ± %5.0f\n', ...
        phase2.num_stas(i), phase2.thold_ms(i), ...
        phase2.thold_activations_mean(i), phase2.thold_activations_std(i), ...
        phase2.thold_hits_mean(i), phase2.thold_hits_std(i), ...
        phase2.thold_expirations_mean(i), phase2.thold_expirations_std(i), ...
        phase2.thold_phantom_count_mean(i), phase2.thold_phantom_count_std(i));
end

%% ═══════════════════════════════════════════════════════════════════
%  4. Phase 3: rho별 T_hold 효과
%  ═══════════════════════════════════════════════════════════════════

fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════╗\n');
fprintf('║  4. rho별 T_hold 효과 (Phase 3)                              ║\n');
fprintf('╚══════════════════════════════════════════════════════════════╝\n\n');

rho_list = unique(phase3.rho);

fprintf('%-6s | %-6s | %10s | %12s | %12s | %10s | %12s\n', ...
    'STA', 'rho', 'Coverage%', 'BaseDelay', 'T_holdDelay', 'Improve%', 'HitRate%');
fprintf('%s\n', repmat('-', 1, 85));

for si = 1:length(sta_list)
    for ri = 1:length(rho_list)
        sta = sta_list(si);
        rho = rho_list(ri);
        
        base_idx = phase1.num_stas == sta & abs(phase1.rho - rho) < 0.01;
        thold_idx = phase3.num_stas == sta & abs(phase3.rho - rho) < 0.01;
        
        if any(base_idx) && any(thold_idx)
            base_delay = phase1.delay_mean_ms_mean(base_idx);
            thold_delay = phase3.delay_mean_ms_mean(thold_idx);
            thold_delay_s = phase3.delay_mean_ms_std(thold_idx);
            coverage = phase3.thold_coverage_mean(thold_idx);
            hit_rate_m = phase3.thold_hit_rate_mean(thold_idx);
            hit_rate_s = phase3.thold_hit_rate_std(thold_idx);
            
            improve = (base_delay - thold_delay) / base_delay * 100;
            
            fprintf('%-6d | %-6.1f | %10.0f | %10.1f | %5.1f ± %4.1f | %+9.1f%% | %5.1f ± %4.1f\n', ...
                sta, rho, coverage, base_delay, thold_delay, thold_delay_s, ...
                improve, hit_rate_m*100, hit_rate_s*100);
        end
    end
end

%% ═══════════════════════════════════════════════════════════════════
%  5. 공정성 분석
%  ═══════════════════════════════════════════════════════════════════

fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════╗\n');
fprintf('║  5. 공정성 분석                                              ║\n');
fprintf('╚══════════════════════════════════════════════════════════════╝\n\n');

fprintf('%-10s | %-6s | %-8s | %15s | %15s\n', ...
    'Phase', 'STA', 'Cond', 'Jain Index', 'MinMax Ratio');
fprintf('%s\n', repmat('-', 1, 65));

% Baseline (Phase 1, rho=0.5만)
for i = 1:height(baseline_rho05)
    fprintf('%-10s | %-6d | rho=%.1f  | %.4f ± %.4f | %.4f ± %.4f\n', ...
        'Baseline', baseline_rho05.num_stas(i), 0.5, ...
        baseline_rho05.jain_index_mean(i), baseline_rho05.jain_index_std(i), ...
        baseline_rho05.min_max_ratio_mean(i), baseline_rho05.min_max_ratio_std(i));
end

% T_hold (Phase 2)
for i = 1:height(phase2)
    fprintf('%-10s | %-6d | %4dms   | %.4f ± %.4f | %.4f ± %.4f\n', ...
        'T_hold', phase2.num_stas(i), phase2.thold_ms(i), ...
        phase2.jain_index_mean(i), phase2.jain_index_std(i), ...
        phase2.min_max_ratio_mean(i), phase2.min_max_ratio_std(i));
end

%% ═══════════════════════════════════════════════════════════════════
%  6. 그래프 생성
%  ═══════════════════════════════════════════════════════════════════

fprintf('\n■ 그래프 생성 중...\n');

% Figure 1: Delay 비교 with error bars
fig1 = figure('Position', [100, 100, 1000, 400]);

for si = 1:length(sta_list)
    sta = sta_list(si);
    subplot(1, length(sta_list), si);
    
    % Baseline
    base_idx = baseline_rho05.num_stas == sta;
    base_delay = baseline_rho05.delay_mean_ms_mean(base_idx);
    base_std = baseline_rho05.delay_mean_ms_std(base_idx);
    
    % T_hold values
    thold_delays = [];
    thold_stds = [];
    for ti = 1:length(thold_list)
        idx = phase2.num_stas == sta & phase2.thold_ms == thold_list(ti);
        thold_delays(ti) = phase2.delay_mean_ms_mean(idx);
        thold_stds(ti) = phase2.delay_mean_ms_std(idx);
    end
    
    x = [0, thold_list'];
    y = [base_delay, thold_delays];
    err = [base_std, thold_stds];
    
    bar(x, y, 0.6, 'FaceColor', [0.3 0.5 0.8]);
    hold on;
    errorbar(x, y, err, 'k.', 'LineWidth', 1.5);
    hold off;
    
    xlabel('T_{hold} (ms)');
    ylabel('Delay (ms)');
    title(sprintf('STA=%d', sta));
    grid on;
end
sgtitle('Delay Comparison (mean ± std)', 'FontSize', 14);
saveas(fig1, fullfile(figures_dir, 'phase2_delay_errorbar.png'));
fprintf('  저장: phase2_delay_errorbar.png\n');

% Figure 2: Hit Rate vs Coverage
fig2 = figure('Position', [100, 550, 800, 400]);

coverages = [];
hit_rates_m = [];
hit_rates_s = [];

for ri = 1:length(rho_list)
    rho = rho_list(ri);
    idx = abs(phase3.rho - rho) < 0.01;
    
    if any(idx)
        coverages(ri) = mean(phase3.thold_coverage_mean(idx));
        hit_rates_m(ri) = mean(phase3.thold_hit_rate_mean(idx)) * 100;
        hit_rates_s(ri) = mean(phase3.thold_hit_rate_std(idx)) * 100;
    end
end

bar(coverages, hit_rates_m, 0.6, 'FaceColor', [0.8 0.4 0.2]);
hold on;
errorbar(coverages, hit_rates_m, hit_rates_s, 'k.', 'LineWidth', 1.5);
hold off;
xlabel('Coverage (%)');
ylabel('Hit Rate (%)');
title('Coverage vs Hit Rate (mean ± std)');
grid on;

saveas(fig2, fullfile(figures_dir, 'phase3_coverage_hitrate.png'));
fprintf('  저장: phase3_coverage_hitrate.png\n');

% Figure 3: Improvement Heatmap
fig3 = figure('Position', [900, 100, 700, 500]);

improve_matrix = zeros(length(sta_list), length(rho_list));
for si = 1:length(sta_list)
    for ri = 1:length(rho_list)
        sta = sta_list(si);
        rho = rho_list(ri);
        
        base_idx = phase1.num_stas == sta & abs(phase1.rho - rho) < 0.01;
        thold_idx = phase3.num_stas == sta & abs(phase3.rho - rho) < 0.01;
        
        if any(base_idx) && any(thold_idx)
            base_delay = phase1.delay_mean_ms_mean(base_idx);
            thold_delay = phase3.delay_mean_ms_mean(thold_idx);
            improve_matrix(si, ri) = (base_delay - thold_delay) / base_delay * 100;
        end
    end
end

imagesc(improve_matrix);
colorbar;
colormap(jet);
set(gca, 'XTick', 1:length(rho_list), 'XTickLabel', arrayfun(@(x) sprintf('%.1f', x), rho_list, 'UniformOutput', false));
set(gca, 'YTick', 1:length(sta_list), 'YTickLabel', arrayfun(@(x) sprintf('%d', x), sta_list, 'UniformOutput', false));
xlabel('rho');
ylabel('Number of STAs');
title('Delay Improvement (%)');

for si = 1:length(sta_list)
    for ri = 1:length(rho_list)
        text(ri, si, sprintf('%.0f%%', improve_matrix(si, ri)), ...
            'HorizontalAlignment', 'center', 'Color', 'white', 'FontWeight', 'bold');
    end
end

saveas(fig3, fullfile(figures_dir, 'phase3_improvement_heatmap.png'));
fprintf('  저장: phase3_improvement_heatmap.png\n');

%% ═══════════════════════════════════════════════════════════════════
%  7. 요약
%  ═══════════════════════════════════════════════════════════════════

fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════╗\n');
fprintf('║  7. 요약                                                     ║\n');
fprintf('╚══════════════════════════════════════════════════════════════╝\n\n');

fprintf('■ Phase 2 (rho=0.5) 최고 성능:\n');
for si = 1:length(sta_list)
    sta = sta_list(si);
    idx = phase2.num_stas == sta;
    
    if any(idx)
        sub_table = phase2(idx, :);
        [min_delay, best_idx] = min(sub_table.delay_mean_ms_mean);
        best_thold = sub_table.thold_ms(best_idx);
        best_delay_std = sub_table.delay_mean_ms_std(best_idx);
        best_hit_rate = sub_table.thold_hit_rate_mean(best_idx);
        
        base_idx = baseline_rho05.num_stas == sta;
        base_delay = baseline_rho05.delay_mean_ms_mean(base_idx);
        improve = (base_delay - min_delay) / base_delay * 100;
        
        fprintf('  STA=%d: T_hold=%dms → Delay %.1f±%.1fms (%.0f%% 개선), HitRate %.1f%%\n', ...
            sta, best_thold, min_delay, best_delay_std, improve, best_hit_rate*100);
    end
end

%% 통계 처리된 결과 CSV 저장
writetable(phase1, fullfile(results_dir, 'phase1_stats.csv'));
writetable(phase2, fullfile(results_dir, 'phase2_stats.csv'));
writetable(phase3, fullfile(results_dir, 'phase3_stats.csv'));
fprintf('\n통계 결과 저장: phase1_stats.csv, phase2_stats.csv, phase3_stats.csv\n');

fprintf('\n분석 완료. 그래프: results/figures/\n');

%% ═══════════════════════════════════════════════════════════════════
%  Helper Function: 조건별 통계 계산
%  ═══════════════════════════════════════════════════════════════════

function [stats_table, groups] = calc_group_stats(raw_table, group_vars)
    % 그룹 찾기
    [groups, ~, group_idx] = unique(raw_table(:, group_vars), 'rows');
    n_groups = height(groups);
    
    % 수치형 변수 찾기
    var_names = raw_table.Properties.VariableNames;
    numeric_vars = {};
    for i = 1:length(var_names)
        if isnumeric(raw_table.(var_names{i})) && ~ismember(var_names{i}, [group_vars, {'run', 'phase'}])
            numeric_vars{end+1} = var_names{i};
        end
    end
    
    % 결과 테이블 초기화
    stats_table = groups;
    stats_table.GroupCount = zeros(n_groups, 1);
    
    for vi = 1:length(numeric_vars)
        var = numeric_vars{vi};
        stats_table.([var '_mean']) = zeros(n_groups, 1);
        stats_table.([var '_std']) = zeros(n_groups, 1);
    end
    
    % 그룹별 통계 계산
    for gi = 1:n_groups
        mask = group_idx == gi;
        stats_table.GroupCount(gi) = sum(mask);
        
        for vi = 1:length(numeric_vars)
            var = numeric_vars{vi};
            values = raw_table.(var)(mask);
            stats_table.([var '_mean'])(gi) = mean(values, 'omitnan');
            stats_table.([var '_std'])(gi) = std(values, 'omitnan');
        end
    end
end