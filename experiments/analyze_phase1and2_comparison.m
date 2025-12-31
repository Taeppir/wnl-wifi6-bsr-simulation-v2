%% analyze_phase1_phase2.m
% Phase 1 (Baseline) vs Phase 2 (T_hold) 포괄적 비교 분석
%
% 파일명 패턴:
%   Phase 1: B-{id}-R{run}_STA{sta}_rho{rho}_run{run}.mat
%   Phase 2: T-{id}-R{run}_STA{sta}_thold{ms}_run{run}.mat
%
% 분석 조건: STA=[20,40], rho=0.5, T_hold=[30,50,70]ms

clear; clc; close all;
addpath(genpath(pwd));

%% ═══════════════════════════════════════════════════════════════════════
%  설정
%  ═══════════════════════════════════════════════════════════════════════

% 데이터 경로
baseline_path = 'results/raw/phase1_baseline/';
thold_path = 'results/raw/phase2_thold_sweep/';

% 분석 대상 파라미터
sta_values = [20, 40];
thold_values = [30, 50, 70];  % ms
rho_target = 0.5;
num_runs = 3;

% 결과 저장 경로
figures_dir = 'results/figures';
if ~exist(figures_dir, 'dir'), mkdir(figures_dir); end

fprintf('╔══════════════════════════════════════════════════════════════════════╗\n');
fprintf('║     Phase 1 vs Phase 2 포괄적 분석                                   ║\n');
fprintf('║     STA: [20, 40] / rho: 0.5 / T_hold: [30, 50, 70]ms               ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════════╝\n\n');

%% ═══════════════════════════════════════════════════════════════════════
%  데이터 로드
%  ═══════════════════════════════════════════════════════════════════════

results = struct();

for si = 1:length(sta_values)
    sta = sta_values(si);
    key = sprintf('STA%d', sta);
    
    %% Baseline 로드 (rho=0.5)
    baseline_data = {};
    pattern = sprintf('%sB-*_STA%d_rho%.1f_run*.mat', baseline_path, sta, rho_target);
    files = dir(pattern);
    
    for fi = 1:length(files)
        loaded = load(fullfile(baseline_path, files(fi).name));
        if isfield(loaded, 'results')
            baseline_data{end+1} = loaded.results;
        end
    end
    
    if ~isempty(baseline_data)
        results.(key).baseline = aggregate_results(baseline_data);
        fprintf('[로드] %s Baseline (rho=0.5): %d files\n', key, length(baseline_data));
    else
        fprintf('[경고] %s Baseline 파일 없음\n', key);
    end
    
    %% T_hold 로드 (30, 50, 70ms)
    for ti = 1:length(thold_values)
        thold = thold_values(ti);
        thold_key = sprintf('thold%d', thold);
        
        thold_data = {};
        pattern = sprintf('%sT-*_STA%d_thold%d_run*.mat', thold_path, sta, thold);
        files = dir(pattern);
        
        for fi = 1:length(files)
            loaded = load(fullfile(thold_path, files(fi).name));
            if isfield(loaded, 'results')
                thold_data{end+1} = loaded.results;
            end
        end
        
        if ~isempty(thold_data)
            results.(key).(thold_key) = aggregate_results(thold_data);
            fprintf('[로드] %s T_hold=%dms: %d files\n', key, thold, length(thold_data));
        else
            fprintf('[경고] %s T_hold=%dms 파일 없음\n', key, thold);
        end
    end
    fprintf('\n');
end

%% ═══════════════════════════════════════════════════════════════════════
%  1. 상세 결과 테이블 출력
%  ═══════════════════════════════════════════════════════════════════════

for si = 1:length(sta_values)
    sta = sta_values(si);
    key = sprintf('STA%d', sta);
    
    if ~isfield(results, key) || ~isfield(results.(key), 'baseline')
        continue;
    end
    
    fprintf('┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓\n');
    fprintf('┃  STA = %d, rho = 0.5                                                         ┃\n', sta);
    fprintf('┣━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━┫\n');
    fprintf('┃ Metric            ┃   Baseline    ┃    T=30ms     ┃    T=50ms     ┃    T=70ms     ┃\n');
    fprintf('┣━━━━━━━━━━━━━━━━━━━╋━━━━━━━━━━━━━━━╋━━━━━━━━━━━━━━━╋━━━━━━━━━━━━━━━╋━━━━━━━━━━━━━━━┫\n');
    
    b = results.(key).baseline;
    t30 = safe_field(results.(key), 'thold30');
    t50 = safe_field(results.(key), 'thold50');
    t70 = safe_field(results.(key), 'thold70');
    
    %% Delay 지표
    fprintf('┃ ▶ DELAY           ┃               ┃               ┃               ┃               ┃\n');
    print_row('  Mean (ms)', b, t30, t50, t70, 'delay_mean', '%.2f');
    print_row('  Std (ms)', b, t30, t50, t70, 'delay_std', '%.2f');
    print_row('  P90 (ms)', b, t30, t50, t70, 'delay_p90', '%.2f');
    print_row('  Max (ms)', b, t30, t50, t70, 'delay_max', '%.1f');
    
    % 개선율
    base_delay = get_val(b, 'delay_mean');
    if base_delay > 0
        fprintf('┃   Improvement     ┃      -        ┃');
        for t = [t30, t50, t70]
            if ~isempty(t)
                imp = (base_delay - get_val(t, 'delay_mean')) / base_delay * 100;
                fprintf('   %+6.1f%%     ┃', imp);
            else
                fprintf('       -       ┃');
            end
        end
        fprintf('\n');
    end
    
    %% Delay 분해
    fprintf('┃ ▶ DELAY DECOMP    ┃               ┃               ┃               ┃               ┃\n');
    print_row('  Initial Wait', b, t30, t50, t70, 'initial_wait_ms', '%.2f');
    print_row('  UORA Contention', b, t30, t50, t70, 'uora_contention_ms', '%.2f');
    print_row('  SA Wait', b, t30, t50, t70, 'sa_wait_ms', '%.2f');
    
    %% Collision 지표 (RU 기준)
    fprintf('┣━━━━━━━━━━━━━━━━━━━╋━━━━━━━━━━━━━━━╋━━━━━━━━━━━━━━━╋━━━━━━━━━━━━━━━╋━━━━━━━━━━━━━━━┫\n');
    fprintf('┃ ▶ COLLISION (RU)  ┃               ┃               ┃               ┃               ┃\n');
    print_row_pct('  Slot Rate', b, t30, t50, t70, 'collision_slot_rate');
    print_row('  Avg Size', b, t30, t50, t70, 'avg_collision_size', '%.2f');
    print_row('  Total Slots', b, t30, t50, t70, 'total_collision_slots', '%.0f');
    
    %% Throughput 지표
    fprintf('┣━━━━━━━━━━━━━━━━━━━╋━━━━━━━━━━━━━━━╋━━━━━━━━━━━━━━━╋━━━━━━━━━━━━━━━╋━━━━━━━━━━━━━━━┫\n');
    fprintf('┃ ▶ THROUGHPUT      ┃               ┃               ┃               ┃               ┃\n');
    print_row('  Total (Mbps)', b, t30, t50, t70, 'throughput_mbps', '%.2f');
    print_row_pct('  RA Utilization', b, t30, t50, t70, 'ra_utilization');
    print_row_pct('  SA Alloc Hit', b, t30, t50, t70, 'sa_utilization');  % 할당 중 실제 전송 비율
    print_row_pct('  Channel Util', b, t30, t50, t70, 'channel_utilization');
    
    %% BSR 지표
    fprintf('┣━━━━━━━━━━━━━━━━━━━╋━━━━━━━━━━━━━━━╋━━━━━━━━━━━━━━━╋━━━━━━━━━━━━━━━╋━━━━━━━━━━━━━━━┫\n');
    fprintf('┃ ▶ BSR             ┃               ┃               ┃               ┃               ┃\n');
    print_row('  Explicit Count', b, t30, t50, t70, 'explicit_bsr_count', '%.0f');
    print_row('  Implicit Count', b, t30, t50, t70, 'implicit_bsr_count', '%.0f');
    print_row_pct('  Explicit Ratio', b, t30, t50, t70, 'explicit_ratio');
    
    %% T_hold 지표
    fprintf('┣━━━━━━━━━━━━━━━━━━━╋━━━━━━━━━━━━━━━╋━━━━━━━━━━━━━━━╋━━━━━━━━━━━━━━━╋━━━━━━━━━━━━━━━┫\n');
    fprintf('┃ ▶ T_HOLD          ┃               ┃               ┃               ┃               ┃\n');
    print_row('  Activations', b, t30, t50, t70, 'thold_activations', '%.0f');
    print_row('  Hits', b, t30, t50, t70, 'thold_hits', '%.0f');
    print_row('  Expirations', b, t30, t50, t70, 'thold_expirations', '%.0f');
    print_row_pct('  Hit Rate', b, t30, t50, t70, 'thold_hit_rate');
    print_row('  Phantom Count', b, t30, t50, t70, 'thold_phantom_count', '%.0f');
    
    %% Fairness 지표
    fprintf('┣━━━━━━━━━━━━━━━━━━━╋━━━━━━━━━━━━━━━╋━━━━━━━━━━━━━━━╋━━━━━━━━━━━━━━━╋━━━━━━━━━━━━━━━┫\n');
    fprintf('┃ ▶ FAIRNESS        ┃               ┃               ┃               ┃               ┃\n');
    print_row('  Jain Index', b, t30, t50, t70, 'jain_index', '%.4f');
    print_row('  Min/Max Ratio', b, t30, t50, t70, 'min_max_ratio', '%.4f');
    
    %% Completion
    fprintf('┣━━━━━━━━━━━━━━━━━━━╋━━━━━━━━━━━━━━━╋━━━━━━━━━━━━━━━╋━━━━━━━━━━━━━━━╋━━━━━━━━━━━━━━━┫\n');
    print_row_pct('  Completion Rate', b, t30, t50, t70, 'completion_rate');
    
    fprintf('┗━━━━━━━━━━━━━━━━━━━┻━━━━━━━━━━━━━━━┻━━━━━━━━━━━━━━━┻━━━━━━━━━━━━━━━┻━━━━━━━━━━━━━━━┛\n\n');
end

%% ═══════════════════════════════════════════════════════════════════════
%  2. 그래프 생성
%  ═══════════════════════════════════════════════════════════════════════

fprintf('■ 그래프 생성 중...\n');

%% Figure 1: Delay Mean 비교
fig1 = figure('Position', [50, 50, 1200, 500], 'Name', 'Delay Mean');
sgtitle('Mean Delay Comparison (\rho=0.5)', 'FontSize', 14, 'FontWeight', 'bold');

for si = 1:length(sta_values)
    sta = sta_values(si);
    key = sprintf('STA%d', sta);
    subplot(1, 2, si);
    
    if isfield(results, key) && isfield(results.(key), 'baseline')
        [delays, stds, labels] = collect_metric(results.(key), thold_values, 'delay_mean', 'delay_mean_std');
        plot_bar_with_values(delays, stds, labels, 'Mean Delay (ms)', sprintf('STA = %d', sta), true);
    end
end
saveas(fig1, fullfile(figures_dir, 'fig1_delay_mean.png'));
fprintf('  저장: fig1_delay_mean.png\n');

%% Figure 2: Delay P90
fig2 = figure('Position', [50, 50, 1200, 500], 'Name', 'Delay P90');
sgtitle('Delay P90 Comparison (\rho=0.5)', 'FontSize', 14, 'FontWeight', 'bold');

for si = 1:length(sta_values)
    sta = sta_values(si);
    key = sprintf('STA%d', sta);
    subplot(1, 2, si);
    
    if isfield(results, key) && isfield(results.(key), 'baseline')
        [vals, stds, labels] = collect_metric(results.(key), thold_values, 'delay_p90', 'delay_p90_std');
        plot_bar_with_values(vals, stds, labels, 'P90 Delay (ms)', sprintf('STA = %d', sta), true);
    end
end
saveas(fig2, fullfile(figures_dir, 'fig2_delay_p90.png'));
fprintf('  저장: fig2_delay_p90.png\n');

%% Figure 3: Delay Std
fig3 = figure('Position', [50, 50, 1200, 500], 'Name', 'Delay Std');
sgtitle('Delay Std Comparison (\rho=0.5)', 'FontSize', 14, 'FontWeight', 'bold');

for si = 1:length(sta_values)
    sta = sta_values(si);
    key = sprintf('STA%d', sta);
    subplot(1, 2, si);
    
    if isfield(results, key) && isfield(results.(key), 'baseline')
        [vals, stds, labels] = collect_metric(results.(key), thold_values, 'delay_std', 'delay_std_std');
        plot_bar_with_values(vals, stds, labels, 'Delay Std (ms)', sprintf('STA = %d', sta), true);
    end
end
saveas(fig3, fullfile(figures_dir, 'fig3_delay_std.png'));
fprintf('  저장: fig3_delay_std.png\n');

%% Figure 4: Delay Max
fig4 = figure('Position', [50, 50, 1200, 500], 'Name', 'Delay Max');
sgtitle('Delay Max Comparison (\rho=0.5)', 'FontSize', 14, 'FontWeight', 'bold');

for si = 1:length(sta_values)
    sta = sta_values(si);
    key = sprintf('STA%d', sta);
    subplot(1, 2, si);
    
    if isfield(results, key) && isfield(results.(key), 'baseline')
        [vals, stds, labels] = collect_metric(results.(key), thold_values, 'delay_max', 'delay_max_std');
        plot_bar_with_values(vals, stds, labels, 'Max Delay (ms)', sprintf('STA = %d', sta), true);
    end
end
saveas(fig4, fullfile(figures_dir, 'fig4_delay_max.png'));
fprintf('  저장: fig4_delay_max.png\n');

%% Figure 5: Delay 분해 (Stacked)
fig5 = figure('Position', [50, 50, 1200, 500], 'Name', 'Delay Decomposition');
sgtitle('Delay Decomposition (\rho=0.5)', 'FontSize', 14, 'FontWeight', 'bold');

for si = 1:length(sta_values)
    sta = sta_values(si);
    key = sprintf('STA%d', sta);
    subplot(1, 2, si);
    
    if isfield(results, key) && isfield(results.(key), 'baseline')
        b = results.(key).baseline;
        decomp_data = [];
        labels = {};
        
        decomp_data = [decomp_data; get_val(b, 'initial_wait_ms'), get_val(b, 'uora_contention_ms'), get_val(b, 'sa_wait_ms')];
        labels{end+1} = 'Base';
        
        for ti = 1:length(thold_values)
            thold_key = sprintf('thold%d', thold_values(ti));
            if isfield(results.(key), thold_key)
                t = results.(key).(thold_key);
                decomp_data = [decomp_data; get_val(t, 'initial_wait_ms'), get_val(t, 'uora_contention_ms'), get_val(t, 'sa_wait_ms')];
                labels{end+1} = sprintf('T=%d', thold_values(ti));
            end
        end
        
        b_bar = bar(decomp_data, 'stacked');
        b_bar(1).FaceColor = [0.4 0.6 0.8];
        b_bar(2).FaceColor = [0.8 0.4 0.4];
        b_bar(3).FaceColor = [0.4 0.8 0.4];
        
        hold on;
        for i = 1:size(decomp_data, 1)
            total = sum(decomp_data(i,:));
            cumsum_vals = [0, cumsum(decomp_data(i,:))];
            for j = 1:3
                if decomp_data(i,j) > total * 0.08
                    y_pos = cumsum_vals(j) + decomp_data(i,j)/2;
                    text(i, y_pos, sprintf('%.1f', decomp_data(i,j)), 'HorizontalAlignment', 'center', 'FontSize', 8, 'Color', 'w', 'FontWeight', 'bold');
                end
            end
            text(i, total + max(sum(decomp_data,2))*0.03, sprintf('Σ%.1f', total), 'HorizontalAlignment', 'center', 'FontSize', 9, 'FontWeight', 'bold');
        end
        hold off;
        
        set(gca, 'XTickLabel', labels);
        ylabel('Delay (ms)');
        title(sprintf('STA = %d', sta));
        legend('Initial Wait', 'UORA Contention', 'SA Wait', 'Location', 'best');
        ylim([0, max(sum(decomp_data,2))*1.15]);
        grid on;
    end
end
saveas(fig5, fullfile(figures_dir, 'fig5_delay_decomp.png'));
fprintf('  저장: fig5_delay_decomp.png\n');

%% Figure 6: Collision Rate (RU 기준)
fig6 = figure('Position', [50, 50, 1200, 500], 'Name', 'Collision Rate');
sgtitle('Collision Rate - RU Slot 기준 (\rho=0.5)', 'FontSize', 14, 'FontWeight', 'bold');

for si = 1:length(sta_values)
    sta = sta_values(si);
    key = sprintf('STA%d', sta);
    subplot(1, 2, si);
    
    if isfield(results, key) && isfield(results.(key), 'baseline')
        [vals, stds, labels] = collect_metric(results.(key), thold_values, 'collision_slot_rate', 'collision_slot_rate_std');
        vals = vals * 100; stds = stds * 100;
        plot_bar_with_values(vals, stds, labels, 'Collision Rate (%)', sprintf('STA = %d', sta), true);
    end
end
saveas(fig6, fullfile(figures_dir, 'fig6_collision_rate.png'));
fprintf('  저장: fig6_collision_rate.png\n');

%% Figure 7: Throughput
fig7 = figure('Position', [50, 50, 1200, 500], 'Name', 'Throughput');
sgtitle('Throughput Comparison (\rho=0.5)', 'FontSize', 14, 'FontWeight', 'bold');

for si = 1:length(sta_values)
    sta = sta_values(si);
    key = sprintf('STA%d', sta);
    subplot(1, 2, si);
    
    if isfield(results, key) && isfield(results.(key), 'baseline')
        [vals, stds, labels] = collect_metric(results.(key), thold_values, 'throughput_mbps', 'throughput_mbps_std');
        plot_bar_with_values(vals, stds, labels, 'Throughput (Mbps)', sprintf('STA = %d', sta), false);
    end
end
saveas(fig7, fullfile(figures_dir, 'fig7_throughput.png'));
fprintf('  저장: fig7_throughput.png\n');

%% Figure 8: RA/SA/Channel 지표
fig8 = figure('Position', [50, 50, 1200, 500], 'Name', 'Utilization');
sgtitle('RA Util / SA Alloc Hit Rate / Channel Util (\rho=0.5)', 'FontSize', 14, 'FontWeight', 'bold');

for si = 1:length(sta_values)
    sta = sta_values(si);
    key = sprintf('STA%d', sta);
    subplot(1, 2, si);
    
    if isfield(results, key) && isfield(results.(key), 'baseline')
        b = results.(key).baseline;
        util_data = [];
        labels = {};
        
        util_data = [util_data; get_val(b, 'ra_utilization')*100, get_val(b, 'sa_utilization')*100, get_val(b, 'channel_utilization')*100];
        labels{end+1} = 'Base';
        
        for ti = 1:length(thold_values)
            thold_key = sprintf('thold%d', thold_values(ti));
            if isfield(results.(key), thold_key)
                t = results.(key).(thold_key);
                util_data = [util_data; get_val(t, 'ra_utilization')*100, get_val(t, 'sa_utilization')*100, get_val(t, 'channel_utilization')*100];
                labels{end+1} = sprintf('T=%d', thold_values(ti));
            end
        end
        
        b_bar = bar(util_data);
        b_bar(1).FaceColor = [0.3 0.5 0.8];
        b_bar(2).FaceColor = [0.8 0.5 0.3];
        b_bar(3).FaceColor = [0.3 0.7 0.3];
        
        hold on;
        for i = 1:size(util_data, 1)
            for j = 1:3
                x_pos = i + (j-2)*0.25;
                text(x_pos, util_data(i,j) + 2, sprintf('%.1f', util_data(i,j)), 'HorizontalAlignment', 'center', 'FontSize', 8, 'FontWeight', 'bold');
            end
        end
        hold off;
        
        set(gca, 'XTickLabel', labels);
        ylabel('Rate (%)');
        title(sprintf('STA = %d', sta));
        legend('RA Util', 'SA Alloc Hit', 'Channel Util', 'Location', 'best');
        ylim([0, 110]);
        grid on;
    end
end
saveas(fig8, fullfile(figures_dir, 'fig8_utilization.png'));
fprintf('  저장: fig8_utilization.png\n');

%% Figure 9: BSR Count (Stacked)
fig9 = figure('Position', [50, 50, 1200, 500], 'Name', 'BSR Count');
sgtitle('BSR Count (\rho=0.5)', 'FontSize', 14, 'FontWeight', 'bold');

for si = 1:length(sta_values)
    sta = sta_values(si);
    key = sprintf('STA%d', sta);
    subplot(1, 2, si);
    
    if isfield(results, key) && isfield(results.(key), 'baseline')
        b = results.(key).baseline;
        bsr_data = [];
        labels = {};
        
        bsr_data = [bsr_data; get_val(b, 'implicit_bsr_count'), get_val(b, 'explicit_bsr_count')];
        labels{end+1} = 'Base';
        
        for ti = 1:length(thold_values)
            thold_key = sprintf('thold%d', thold_values(ti));
            if isfield(results.(key), thold_key)
                t = results.(key).(thold_key);
                bsr_data = [bsr_data; get_val(t, 'implicit_bsr_count'), get_val(t, 'explicit_bsr_count')];
                labels{end+1} = sprintf('T=%d', thold_values(ti));
            end
        end
        
        b_bar = bar(bsr_data, 'stacked');
        b_bar(1).FaceColor = [0.5 0.7 0.5];
        b_bar(2).FaceColor = [0.8 0.5 0.3];
        
        hold on;
        total_bsr = sum(bsr_data, 2);
        for i = 1:size(bsr_data, 1)
            if bsr_data(i,1) > 0
                text(i, bsr_data(i,1)/2, sprintf('%.0f', bsr_data(i,1)), 'HorizontalAlignment', 'center', 'FontSize', 8, 'Color', 'w', 'FontWeight', 'bold');
            end
            if bsr_data(i,2) > total_bsr(i) * 0.05
                text(i, bsr_data(i,1) + bsr_data(i,2)/2, sprintf('%.0f', bsr_data(i,2)), 'HorizontalAlignment', 'center', 'FontSize', 8, 'Color', 'w', 'FontWeight', 'bold');
            end
            exp_ratio = bsr_data(i, 2) / total_bsr(i) * 100;
            text(i, total_bsr(i) + max(total_bsr)*0.03, sprintf('Σ%.0f\nExp:%.1f%%', total_bsr(i), exp_ratio), 'HorizontalAlignment', 'center', 'FontSize', 8, 'FontWeight', 'bold');
        end
        hold off;
        
        set(gca, 'XTickLabel', labels);
        ylabel('BSR Count');
        title(sprintf('STA = %d', sta));
        legend('Implicit BSR', 'Explicit BSR', 'Location', 'best');
        ylim([0, max(total_bsr)*1.2]);
        grid on;
    end
end
saveas(fig9, fullfile(figures_dir, 'fig9_bsr_count.png'));
fprintf('  저장: fig9_bsr_count.png\n');

%% Figure 10: T_hold Hit Rate
fig10 = figure('Position', [50, 50, 1200, 500], 'Name', 'Hit Rate');
sgtitle('T_{hold} Hit Rate (\rho=0.5)', 'FontSize', 14, 'FontWeight', 'bold');

for si = 1:length(sta_values)
    sta = sta_values(si);
    key = sprintf('STA%d', sta);
    subplot(1, 2, si);
    
    if isfield(results, key)
        hit_rates = []; hit_stds = []; labels = {};
        for ti = 1:length(thold_values)
            thold_key = sprintf('thold%d', thold_values(ti));
            if isfield(results.(key), thold_key)
                t = results.(key).(thold_key);
                hit_rates = [hit_rates, get_val(t, 'thold_hit_rate') * 100];
                hit_stds = [hit_stds, get_val(t, 'thold_hit_rate_std') * 100];
                labels{end+1} = sprintf('T=%d', thold_values(ti));
            end
        end
        
        if ~isempty(hit_rates)
            x = 1:length(hit_rates);
            bar(x, hit_rates, 0.6, 'FaceColor', [0.3 0.7 0.3]);
            hold on;
            errorbar(x, hit_rates, hit_stds, 'k.', 'LineWidth', 1.5);
            for i = 1:length(hit_rates)
                text(i, hit_rates(i) + hit_stds(i) + 3, sprintf('%.1f%%', hit_rates(i)), 'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'FontSize', 10);
            end
            hold off;
            set(gca, 'XTick', x, 'XTickLabel', labels);
            ylabel('Hit Rate (%)');
            title(sprintf('STA = %d', sta));
            ylim([0, 100]);
            grid on;
        end
    end
end
saveas(fig10, fullfile(figures_dir, 'fig10_hit_rate.png'));
fprintf('  저장: fig10_hit_rate.png\n');

%% Figure 11: T_hold Details (Hits, Expirations, Phantom)
fig11 = figure('Position', [50, 50, 1200, 500], 'Name', 'T_hold Details');
sgtitle('T_{hold} Details (\rho=0.5)', 'FontSize', 14, 'FontWeight', 'bold');

for si = 1:length(sta_values)
    sta = sta_values(si);
    key = sprintf('STA%d', sta);
    subplot(1, 2, si);
    
    if isfield(results, key)
        thold_data = []; labels = {};
        for ti = 1:length(thold_values)
            thold_key = sprintf('thold%d', thold_values(ti));
            if isfield(results.(key), thold_key)
                t = results.(key).(thold_key);
                thold_data = [thold_data; get_val(t, 'thold_hits'), get_val(t, 'thold_expirations'), get_val(t, 'thold_phantom_count')];
                labels{end+1} = sprintf('T=%d', thold_values(ti));
            end
        end
        
        if ~isempty(thold_data)
            b_bar = bar(thold_data);
            b_bar(1).FaceColor = [0.3 0.7 0.3];
            b_bar(2).FaceColor = [0.8 0.4 0.4];
            b_bar(3).FaceColor = [0.6 0.6 0.6];
            
            hold on;
            for i = 1:size(thold_data, 1)
                for j = 1:3
                    x_pos = i + (j-2)*0.25;
                    y_val = thold_data(i, j);
                    if y_val > 0
                        text(x_pos, y_val + max(thold_data(:))*0.03, sprintf('%.0f', y_val), 'HorizontalAlignment', 'center', 'FontSize', 8, 'FontWeight', 'bold');
                    end
                end
                total_act = thold_data(i,1) + thold_data(i,2);
                if total_act > 0
                    hit_rate = thold_data(i,1) / total_act * 100;
                    text(i, -max(thold_data(:))*0.08, sprintf('HR:%.0f%%', hit_rate), 'HorizontalAlignment', 'center', 'FontSize', 9, 'Color', 'b', 'FontWeight', 'bold');
                end
            end
            hold off;
            
            set(gca, 'XTickLabel', labels);
            ylabel('Count');
            title(sprintf('STA = %d', sta));
            legend('Hits', 'Expirations', 'Phantom', 'Location', 'best');
            ylim([-max(thold_data(:))*0.15, max(thold_data(:))*1.15]);
            grid on;
        end
    end
end
saveas(fig11, fullfile(figures_dir, 'fig11_thold_details.png'));
fprintf('  저장: fig11_thold_details.png\n');

%% Figure 12: Fairness (Jain Index & Min/Max Ratio)
fig12 = figure('Position', [50, 50, 1200, 500], 'Name', 'Fairness');
sgtitle('Fairness Metrics (\rho=0.5)', 'FontSize', 14, 'FontWeight', 'bold');

for si = 1:length(sta_values)
    sta = sta_values(si);
    key = sprintf('STA%d', sta);
    subplot(1, 2, si);
    
    if isfield(results, key) && isfield(results.(key), 'baseline')
        b = results.(key).baseline;
        fairness_data = []; labels = {};
        
        fairness_data = [fairness_data; get_val(b, 'jain_index'), get_val(b, 'min_max_ratio')];
        labels{end+1} = 'Base';
        
        for ti = 1:length(thold_values)
            thold_key = sprintf('thold%d', thold_values(ti));
            if isfield(results.(key), thold_key)
                t = results.(key).(thold_key);
                fairness_data = [fairness_data; get_val(t, 'jain_index'), get_val(t, 'min_max_ratio')];
                labels{end+1} = sprintf('T=%d', thold_values(ti));
            end
        end
        
        b_bar = bar(fairness_data);
        b_bar(1).FaceColor = [0.3 0.5 0.8];
        b_bar(2).FaceColor = [0.8 0.5 0.3];
        
        hold on;
        for i = 1:size(fairness_data, 1)
            for j = 1:2
                x_pos = i + (j-1.5)*0.15;
                text(x_pos, fairness_data(i,j) + 0.03, sprintf('%.3f', fairness_data(i,j)), 'HorizontalAlignment', 'center', 'FontSize', 8, 'FontWeight', 'bold', 'Rotation', 45);
            end
        end
        hold off;
        
        set(gca, 'XTickLabel', labels);
        ylabel('Index Value');
        title(sprintf('STA = %d', sta));
        legend('Jain Index', 'Min/Max Ratio', 'Location', 'best');
        ylim([0 1.15]);
        grid on;
    end
end
saveas(fig12, fullfile(figures_dir, 'fig12_fairness.png'));
fprintf('  저장: fig12_fairness.png\n');

%% Figure 13: Completion Rate
fig13 = figure('Position', [50, 50, 1200, 500], 'Name', 'Completion Rate');
sgtitle('Completion Rate (\rho=0.5)', 'FontSize', 14, 'FontWeight', 'bold');

for si = 1:length(sta_values)
    sta = sta_values(si);
    key = sprintf('STA%d', sta);
    subplot(1, 2, si);
    
    if isfield(results, key) && isfield(results.(key), 'baseline')
        [vals, stds, labels] = collect_metric(results.(key), thold_values, 'completion_rate', 'completion_rate_std');
        vals = vals * 100; stds = stds * 100;
        plot_bar_with_values(vals, stds, labels, 'Completion Rate (%)', sprintf('STA = %d', sta), false);
        ylim([0 105]);
    end
end
saveas(fig13, fullfile(figures_dir, 'fig13_completion.png'));
fprintf('  저장: fig13_completion.png\n');

%% Figure 14: Summary Dashboard
fig14 = figure('Position', [50, 50, 1600, 900], 'Name', 'Summary');
sgtitle('Performance Summary Dashboard (\rho=0.5)', 'FontSize', 16, 'FontWeight', 'bold');

metrics = {
    'delay_mean', 'Delay Mean (ms)', 1, '%.1f';
    'delay_p90', 'Delay P90 (ms)', 1, '%.1f';
    'collision_slot_rate', 'Collision (%)', 100, '%.1f';
    'throughput_mbps', 'Throughput (Mbps)', 1, '%.2f';
    'thold_hit_rate', 'Hit Rate (%)', 100, '%.1f';
    'jain_index', 'Jain Index', 1, '%.3f';
};

for mi = 1:size(metrics, 1)
    subplot(2, 3, mi);
    
    plot_data = []; labels_sta = {};
    for si = 1:length(sta_values)
        sta = sta_values(si);
        key = sprintf('STA%d', sta);
        
        if isfield(results, key) && isfield(results.(key), 'baseline')
            b = results.(key).baseline;
            row = [get_val(b, metrics{mi,1}) * metrics{mi,3}];
            for ti = 1:length(thold_values)
                thold_key = sprintf('thold%d', thold_values(ti));
                if isfield(results.(key), thold_key)
                    t = results.(key).(thold_key);
                    row = [row, get_val(t, metrics{mi,1}) * metrics{mi,3}];
                else
                    row = [row, 0];
                end
            end
            plot_data = [plot_data; row];
            labels_sta{end+1} = sprintf('STA=%d', sta);
        end
    end
    
    if ~isempty(plot_data)
        b_bar = bar(plot_data);
        colors = [0.3 0.3 0.8; 0.2 0.7 0.3; 0.9 0.6 0.1; 0.8 0.2 0.2];
        for bi = 1:length(b_bar)
            b_bar(bi).FaceColor = colors(bi,:);
        end
        
        hold on;
        for i = 1:size(plot_data, 1)
            for j = 1:size(plot_data, 2)
                x_pos = i + (j - 2.5) * 0.22;
                y_pos = plot_data(i, j);
                if y_pos > 0
                    text(x_pos, y_pos + max(plot_data(:))*0.05, sprintf(metrics{mi,4}, y_pos), 'HorizontalAlignment', 'center', 'FontSize', 7, 'Rotation', 45);
                end
            end
        end
        hold off;
        
        set(gca, 'XTickLabel', labels_sta);
        ylabel(metrics{mi,2});
        title(metrics{mi,2});
        legend(['Base', arrayfun(@(x) sprintf('T=%d', x), thold_values, 'UniformOutput', false)], 'Location', 'best', 'FontSize', 7);
        grid on;
    end
end
saveas(fig14, fullfile(figures_dir, 'fig14_summary.png'));
fprintf('  저장: fig14_summary.png\n');

fprintf('\n■ 그래프 생성 완료: %d개 → %s\n', 14, figures_dir);

%% ═══════════════════════════════════════════════════════════════════════
%  결과 저장
%  ═══════════════════════════════════════════════════════════════════════

save(fullfile(figures_dir, '..', 'analysis_results.mat'), 'results', 'sta_values', 'thold_values');
fprintf('결과 저장: results/analysis_results.mat\n');

%% ═══════════════════════════════════════════════════════════════════════
%  Helper Functions
%  ═══════════════════════════════════════════════════════════════════════

function [vals, stds, labels] = collect_metric(result_struct, thold_values, field, std_field)
    vals = [get_val(result_struct.baseline, field)];
    stds = [get_val(result_struct.baseline, std_field)];
    labels = {'Base'};
    
    for ti = 1:length(thold_values)
        thold_key = sprintf('thold%d', thold_values(ti));
        if isfield(result_struct, thold_key)
            t = result_struct.(thold_key);
            vals = [vals, get_val(t, field)];
            stds = [stds, get_val(t, std_field)];
            labels{end+1} = sprintf('T=%d', thold_values(ti));
        end
    end
end

function plot_bar_with_values(vals, stds, labels, y_label, title_str, show_improve)
    x = 1:length(vals);
    colors = [0.3 0.3 0.8; 0.2 0.7 0.3; 0.9 0.6 0.1; 0.8 0.2 0.2];
    
    hold on;
    for i = 1:length(vals)
        bar(x(i), vals(i), 0.6, 'FaceColor', colors(i,:));
    end
    errorbar(x, vals, stds, 'k.', 'LineWidth', 1.5, 'CapSize', 10);
    
    base_val = vals(1);
    max_val = max(vals + stds);
    
    for i = 1:length(vals)
        % 값 표시
        if vals(i) > max_val * 0.3
            text(i, vals(i)/2, sprintf('%.1f±%.1f', vals(i), stds(i)), 'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'FontSize', 9, 'Color', 'w');
        else
            text(i, vals(i) + stds(i) + max_val*0.02, sprintf('%.1f±%.1f', vals(i), stds(i)), 'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'FontSize', 9);
        end
        
        % 개선율 (Baseline 제외)
        if show_improve && i > 1 && base_val > 0
            imp = (base_val - vals(i)) / base_val * 100;
            text(i, max_val * 1.08, sprintf('%.0f%%↓', imp), 'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'FontSize', 10, 'Color', 'r');
        end
    end
    hold off;
    
    set(gca, 'XTick', x, 'XTickLabel', labels);
    ylabel(y_label);
    title(title_str);
    if show_improve
        ylim([0, max_val * 1.2]);
    end
    grid on;
end

function agg = aggregate_results(data_cell)
    if isempty(data_cell)
        agg = [];
        return;
    end
    
    agg = struct();
    
    % 2단계 중첩 필드
    fields_to_agg = {
        'delay', 'mean_ms', 'delay_mean';
        'delay', 'std_ms', 'delay_std';
        'delay', 'p90_ms', 'delay_p90';
        'delay', 'p99_ms', 'delay_p99';
        'delay', 'max_ms', 'delay_max';
        'uora', 'collision_rate', 'collision_rate';
        'uora', 'collision_slot_rate', 'collision_slot_rate';
        'uora', 'avg_collision_size', 'avg_collision_size';
        'uora', 'total_collision_slots', 'total_collision_slots';
        'throughput', 'total_mbps', 'throughput_mbps';
        'throughput', 'ra_utilization', 'ra_utilization';
        'throughput', 'sa_utilization', 'sa_utilization';
        'throughput', 'channel_utilization', 'channel_utilization';
        'bsr', 'explicit_count', 'explicit_bsr_count';
        'bsr', 'implicit_count', 'implicit_bsr_count';
        'bsr', 'explicit_ratio', 'explicit_ratio';
        'thold', 'activations', 'thold_activations';
        'thold', 'hits', 'thold_hits';
        'thold', 'expirations', 'thold_expirations';
        'thold', 'hit_rate', 'thold_hit_rate';
        'thold', 'phantom_count', 'thold_phantom_count';
        'fairness', 'jain_index', 'jain_index';
        'fairness', 'min_max_ratio', 'min_max_ratio';
        'packets', 'completion_rate', 'completion_rate';
    };
    
    for fi = 1:size(fields_to_agg, 1)
        parent = fields_to_agg{fi, 1};
        child = fields_to_agg{fi, 2};
        out_name = fields_to_agg{fi, 3};
        
        values = [];
        for i = 1:length(data_cell)
            r = data_cell{i};
            if isfield(r, parent) && isfield(r.(parent), child)
                values = [values, r.(parent).(child)];
            end
        end
        
        if ~isempty(values)
            agg.(out_name) = mean(values);
            agg.([out_name '_std']) = std(values);
        else
            agg.(out_name) = 0;
            agg.([out_name '_std']) = 0;
        end
    end
    
    % 3단계 중첩 필드 (delay_decomp.XXX.mean_ms)
    decomp_fields = {'initial_wait', 'uora_contention', 'sa_wait'};
    for fi = 1:length(decomp_fields)
        sub_field = decomp_fields{fi};
        out_name = [sub_field '_ms'];
        
        values = [];
        for i = 1:length(data_cell)
            r = data_cell{i};
            if isfield(r, 'delay_decomp') && isfield(r.delay_decomp, sub_field) && isfield(r.delay_decomp.(sub_field), 'mean_ms')
                values = [values, r.delay_decomp.(sub_field).mean_ms];
            end
        end
        
        if ~isempty(values)
            agg.(out_name) = mean(values);
            agg.([out_name '_std']) = std(values);
        else
            agg.(out_name) = 0;
            agg.([out_name '_std']) = 0;
        end
    end
end

function s = safe_field(parent, field)
    if isfield(parent, field)
        s = parent.(field);
    else
        s = [];
    end
end

function val = get_val(s, field)
    if isempty(s) || ~isfield(s, field)
        val = 0;
    else
        val = s.(field);
    end
end

function print_row(name, b, t30, t50, t70, field, fmt)
    fprintf('┃ %-17s ┃', name);
    
    val = get_val(b, field);
    std_val = get_val(b, [field '_std']);
    if std_val > 0
        fprintf([' %6' fmt(3:end) '±%5' fmt(3:end) ' ┃'], val, std_val);
    else
        fprintf([' %6' fmt(3:end) '       ┃'], val);
    end
    
    for t = {t30, t50, t70}
        if ~isempty(t{1})
            val = get_val(t{1}, field);
            std_val = get_val(t{1}, [field '_std']);
            if std_val > 0
                fprintf([' %6' fmt(3:end) '±%5' fmt(3:end) ' ┃'], val, std_val);
            else
                fprintf([' %6' fmt(3:end) '       ┃'], val);
            end
        else
            fprintf('       -       ┃');
        end
    end
    fprintf('\n');
end

function print_row_pct(name, b, t30, t50, t70, field)
    fprintf('┃ %-17s ┃', name);
    
    val = get_val(b, field) * 100;
    std_val = get_val(b, [field '_std']) * 100;
    if std_val > 0
        fprintf(' %5.1f%%±%4.1f%% ┃', val, std_val);
    else
        fprintf(' %5.1f%%       ┃', val);
    end
    
    for t = {t30, t50, t70}
        if ~isempty(t{1})
            val = get_val(t{1}, field) * 100;
            std_val = get_val(t{1}, [field '_std']) * 100;
            if std_val > 0
                fprintf(' %5.1f%%±%4.1f%% ┃', val, std_val);
            else
                fprintf(' %5.1f%%       ┃', val);
            end
        else
            fprintf('       -       ┃');
        end
    end
    fprintf('\n');
end