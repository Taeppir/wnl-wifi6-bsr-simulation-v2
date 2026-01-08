%% analyze_delay_boxplot.m
% Boxplot 스타일 지연 분포 시각화 (Toolbox 없이 직접 구현)
% 
% Boxplot: 박스=Q1~Q3, 중간선=P50, 수염=Min~Max

clear; clc;
fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════════╗\n');
fprintf('║            지연 분포 Boxplot 분석                                 ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════╝\n\n');

%% 데이터 로드
m0m1_file = 'results/main_m0_m1/results.mat';
m2_file = 'results/main_m2/results.mat';

load(m0m1_file, 'results'); results_m0m1 = results;
load(m2_file, 'results'); results_m2 = results;
fprintf('[데이터 로드 완료]\n\n');

%% 설정
scenarios = {'A', 'B', 'C'};
scenario_desc = {'VoIP-like', 'Video-like', 'IoT-like'};
thold_values = [30, 50, 70];
num_seeds = 10;

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
    
    % M0 (T30, T50, T70)
    for th = thold_values
        x_pos = x_pos + 1;
        delays = get_all_delays(results_m0m1, sc, th, 'M0', num_seeds);
        draw_boxplot(x_pos, delays, colors.M0, 0.6);
        x_ticks(end+1) = x_pos;
        x_labels{end+1} = sprintf('%d', th);
    end
    
    % 구분선
    xline(x_pos + 0.5, '-', 'Color', [0.7 0.7 0.7], 'LineWidth', 1);
    
    % M1 (T30, T50, T70)
    for th = thold_values
        x_pos = x_pos + 1;
        delays = get_all_delays(results_m0m1, sc, th, 'M1(5)', num_seeds);
        draw_boxplot(x_pos, delays, colors.M1, 0.6);
        x_ticks(end+1) = x_pos;
        x_labels{end+1} = sprintf('%d', th);
    end
    
    % 구분선
    xline(x_pos + 0.5, '-', 'Color', [0.7 0.7 0.7], 'LineWidth', 1);
    
    % M2 (T30, T50, T70)
    for th = thold_values
        x_pos = x_pos + 1;
        delays = get_all_delays(results_m2, sc, th, 'M2', num_seeds);
        draw_boxplot(x_pos, delays, colors.M2, 0.6);
        x_ticks(end+1) = x_pos;
        x_labels{end+1} = sprintf('%d', th);
    end
    
    % Baseline 기준선 제거 (주석처리)
    % yline(base_median, '--', 'Color', colors.Baseline, 'LineWidth', 1.5);
    
    hold off;
    
    set(gca, 'XTick', x_ticks, 'XTickLabel', x_labels, 'FontSize', 8);
    xlim([0.5, x_pos + 0.5]);
    ylim([0, 300]);  % y축 고정
    ylabel('Delay (ms)', 'FontSize', 10);
    title(sprintf('시나리오 %s', sc), 'FontSize', 12);
    
    % 그룹명 추가
    yl = ylim;
    text(1, yl(1) - (yl(2)-yl(1))*0.10, '기존 방식', 'HorizontalAlignment', 'center', ...
        'FontSize', 9, 'FontWeight', 'bold', 'Color', colors.Baseline);
    text(3, yl(1) - (yl(2)-yl(1))*0.10, '기법 1', 'HorizontalAlignment', 'center', ...
        'FontSize', 9, 'FontWeight', 'bold', 'Color', colors.M0);
    text(6, yl(1) - (yl(2)-yl(1))*0.10, '기법 2', 'HorizontalAlignment', 'center', ...
        'FontSize', 9, 'FontWeight', 'bold', 'Color', colors.M1);
    text(9, yl(1) - (yl(2)-yl(1))*0.10, '기법 3', 'HorizontalAlignment', 'center', ...
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
% 흰색과 섞어서 밝기 조절
brighten = @(c, f) c + (1-c) * f;  % f=0이면 원색, f=1이면 흰색

colors_M0 = [base_M0;                    % T30 - 원색
             brighten(base_M0, 0.2);     % T50 - 20% 밝게
             brighten(base_M0, 0.4)];    % T70 - 40% 밝게

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
    
    % Baseline (검은색, 다른 선과 같은 두께)
    base_d = get_all_delays(results_m0m1, sc, 0, 'Baseline', num_seeds);
    [x_base, f_base] = calc_cdf(base_d);
    plot(x_base, f_base, 'Color', [0.2 0.2 0.2], 'LineStyle', '-', 'LineWidth', 1.5);
    
    % 기법 1 (M0) - 파란색 계열
    for th_idx = 1:3
        th = thold_values(th_idx);
        d = get_all_delays(results_m0m1, sc, th, 'M0', num_seeds);
        [x_cdf, f_cdf] = calc_cdf(d);
        plot(x_cdf, f_cdf, 'Color', colors_M0(th_idx,:), 'LineStyle', '-', 'LineWidth', 1.5);
    end
    
    % 기법 2 (M1) - 주황색 계열
    for th_idx = 1:3
        th = thold_values(th_idx);
        d = get_all_delays(results_m0m1, sc, th, 'M1(5)', num_seeds);
        [x_cdf, f_cdf] = calc_cdf(d);
        plot(x_cdf, f_cdf, 'Color', colors_M1(th_idx,:), 'LineStyle', '-', 'LineWidth', 1.5);
    end
    
    % 기법 3 (M2) - 초록색 계열
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
        legend({'기존 방식', ...
                '기법1 T30', '기법1 T50', '기법1 T70', ...
                '기법2 T30', '기법2 T50', '기법2 T70', ...
                '기법3 T30', '기법3 T50', '기법3 T70'}, ...
                'Location', 'southeast', 'FontSize', 7);
    end
end

%% Figure 3: Mean Delay (Error bar = P10~P90) - 선 연결 없음
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
    
    % M0, M1, M2 데이터 수집
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
    
    % Baseline도 각 T_hold 위치에 동일하게 표시
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
    
    xlabel('T_{hold} (ms)', 'FontSize', 11);
    ylabel('Mean Delay (ms)', 'FontSize', 11);
    title(sprintf('시나리오 %s', sc), 'FontSize', 12);
    xlim([22 78]);
    set(gca, 'XTick', thold_values);
    grid on;
    
    if sc_idx == 3
        legend({'기존 방식', '기법 1', '기법 2', '기법 3'}, 'Location', 'northeast', 'FontSize', 9);
    end
end

%% Figure 4: Median Delay (Error bar = P10~P90) - 선 연결 없음
figure('Name', 'Median Delay Errorbar', 'Position', [100 100 1500 400]);

for sc_idx = 1:3
    sc = scenarios{sc_idx};
    subplot(1, 3, sc_idx);
    hold on;
    
    % Baseline 데이터
    base_d = get_all_delays(results_m0m1, sc, 0, 'Baseline', num_seeds);
    base_med = calc_median(base_d);
    base_p10 = calc_quantile(base_d, 0.10);
    base_p90 = calc_quantile(base_d, 0.90);
    
    % M0, M1, M2 데이터 수집
    med_m0 = zeros(1, 3); p10_m0 = zeros(1, 3); p90_m0 = zeros(1, 3);
    med_m1 = zeros(1, 3); p10_m1 = zeros(1, 3); p90_m1 = zeros(1, 3);
    med_m2 = zeros(1, 3); p10_m2 = zeros(1, 3); p90_m2 = zeros(1, 3);
    
    for th_idx = 1:3
        th = thold_values(th_idx);
        
        d = get_all_delays(results_m0m1, sc, th, 'M0', num_seeds);
        med_m0(th_idx) = calc_median(d);
        p10_m0(th_idx) = calc_quantile(d, 0.10);
        p90_m0(th_idx) = calc_quantile(d, 0.90);
        
        d = get_all_delays(results_m0m1, sc, th, 'M1(5)', num_seeds);
        med_m1(th_idx) = calc_median(d);
        p10_m1(th_idx) = calc_quantile(d, 0.10);
        p90_m1(th_idx) = calc_quantile(d, 0.90);
        
        d = get_all_delays(results_m2, sc, th, 'M2', num_seeds);
        med_m2(th_idx) = calc_median(d);
        p10_m2(th_idx) = calc_quantile(d, 0.10);
        p90_m2(th_idx) = calc_quantile(d, 0.90);
    end
    
    % 오프셋
    offset = 2;
    
    % Baseline도 각 T_hold 위치에 동일하게 표시
    base_meds = repmat(base_med, 1, 3);
    base_p10s = repmat(base_p10, 1, 3);
    base_p90s = repmat(base_p90, 1, 3);
    
    errorbar(thold_values - 1.5*offset, base_meds, base_meds - base_p10s, base_p90s - base_meds, 'd', ...
        'Color', colors.Baseline, 'LineWidth', 1.5, 'MarkerSize', 8, 'MarkerFaceColor', colors.Baseline, 'CapSize', 5);
    errorbar(thold_values - 0.5*offset, med_m0, med_m0 - p10_m0, p90_m0 - med_m0, 'o', ...
        'Color', colors.M0, 'LineWidth', 1.5, 'MarkerSize', 8, 'MarkerFaceColor', colors.M0, 'CapSize', 5);
    errorbar(thold_values + 0.5*offset, med_m1, med_m1 - p10_m1, p90_m1 - med_m1, 's', ...
        'Color', colors.M1, 'LineWidth', 1.5, 'MarkerSize', 8, 'MarkerFaceColor', colors.M1, 'CapSize', 5);
    errorbar(thold_values + 1.5*offset, med_m2, med_m2 - p10_m2, p90_m2 - med_m2, '^', ...
        'Color', colors.M2, 'LineWidth', 1.5, 'MarkerSize', 8, 'MarkerFaceColor', colors.M2, 'CapSize', 5);
    
    hold off;
    
    xlabel('T_{hold} (ms)', 'FontSize', 11);
    ylabel('Median Delay (ms)', 'FontSize', 11);
    title(sprintf('시나리오 %s', sc), 'FontSize', 12);
    xlim([22 78]);
    set(gca, 'XTick', thold_values);
    grid on;
    
    if sc_idx == 3
        legend({'기존 방식', '기법 1', '기법 2', '기법 3'}, 'Location', 'northeast', 'FontSize', 9);
    end
end

%% Figure 5: Mean Delay (음영 = P10~P90) - 선 연결 있음
figure('Name', 'Mean Delay Shaded', 'Position', [100 100 1500 400]);

for sc_idx = 1:3
    sc = scenarios{sc_idx};
    subplot(1, 3, sc_idx);
    hold on;
    
    % Baseline 데이터
    base_d = get_all_delays(results_m0m1, sc, 0, 'Baseline', num_seeds);
    base_mean = mean(base_d);
    base_p10 = calc_quantile(base_d, 0.10);
    base_p90 = calc_quantile(base_d, 0.90);
    
    % M0, M1, M2 데이터 수집
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
    
    % Baseline도 동일한 값으로 배열 생성
    base_means = repmat(base_mean, 1, 3);
    base_p10s = repmat(base_p10, 1, 3);
    base_p90s = repmat(base_p90, 1, 3);
    
    % 음영 영역 그리기 (P10~P90)
    x_fill = [thold_values, fliplr(thold_values)];
    
    fill(x_fill, [base_p10s, fliplr(base_p90s)], colors.Baseline, 'FaceAlpha', 0.2, 'EdgeColor', 'none');
    fill(x_fill, [p10_m0, fliplr(p90_m0)], colors.M0, 'FaceAlpha', 0.2, 'EdgeColor', 'none');
    fill(x_fill, [p10_m1, fliplr(p90_m1)], colors.M1, 'FaceAlpha', 0.2, 'EdgeColor', 'none');
    fill(x_fill, [p10_m2, fliplr(p90_m2)], colors.M2, 'FaceAlpha', 0.2, 'EdgeColor', 'none');
    
    % 평균선 그리기
    plot(thold_values, base_means, '-d', 'Color', colors.Baseline, 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', colors.Baseline);
    plot(thold_values, mean_m0, '-o', 'Color', colors.M0, 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', colors.M0);
    plot(thold_values, mean_m1, '-s', 'Color', colors.M1, 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', colors.M1);
    plot(thold_values, mean_m2, '-^', 'Color', colors.M2, 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', colors.M2);
    
    hold off;
    
    xlabel('T_{hold} (ms)', 'FontSize', 11);
    ylabel('Mean Delay (ms)', 'FontSize', 11);
    title(sprintf('시나리오 %s', sc), 'FontSize', 12);
    xlim([25 75]);
    set(gca, 'XTick', thold_values);
    grid on;
    
    if sc_idx == 3
        legend({'기존 방식 (P10-P90)', '기법 1 (P10-P90)', '기법 2 (P10-P90)', '기법 3 (P10-P90)', ...
                '기존 방식', '기법 1', '기법 2', '기법 3'}, ...
            'Location', 'northeast', 'FontSize', 7);
    end
end

%% Figure 6: Median Delay (음영 = P10~P90) - 선 연결 있음
figure('Name', 'Median Delay Shaded', 'Position', [100 100 1500 400]);

for sc_idx = 1:3
    sc = scenarios{sc_idx};
    subplot(1, 3, sc_idx);
    hold on;
    
    % Baseline 데이터
    base_d = get_all_delays(results_m0m1, sc, 0, 'Baseline', num_seeds);
    base_med = calc_median(base_d);
    base_p10 = calc_quantile(base_d, 0.10);
    base_p90 = calc_quantile(base_d, 0.90);
    
    % M0, M1, M2 데이터 수집
    med_m0 = zeros(1, 3); p10_m0 = zeros(1, 3); p90_m0 = zeros(1, 3);
    med_m1 = zeros(1, 3); p10_m1 = zeros(1, 3); p90_m1 = zeros(1, 3);
    med_m2 = zeros(1, 3); p10_m2 = zeros(1, 3); p90_m2 = zeros(1, 3);
    
    for th_idx = 1:3
        th = thold_values(th_idx);
        
        d = get_all_delays(results_m0m1, sc, th, 'M0', num_seeds);
        med_m0(th_idx) = calc_median(d);
        p10_m0(th_idx) = calc_quantile(d, 0.10);
        p90_m0(th_idx) = calc_quantile(d, 0.90);
        
        d = get_all_delays(results_m0m1, sc, th, 'M1(5)', num_seeds);
        med_m1(th_idx) = calc_median(d);
        p10_m1(th_idx) = calc_quantile(d, 0.10);
        p90_m1(th_idx) = calc_quantile(d, 0.90);
        
        d = get_all_delays(results_m2, sc, th, 'M2', num_seeds);
        med_m2(th_idx) = calc_median(d);
        p10_m2(th_idx) = calc_quantile(d, 0.10);
        p90_m2(th_idx) = calc_quantile(d, 0.90);
    end
    
    % Baseline도 동일한 값으로 배열 생성
    base_meds = repmat(base_med, 1, 3);
    base_p10s = repmat(base_p10, 1, 3);
    base_p90s = repmat(base_p90, 1, 3);
    
    % 음영 영역 그리기 (P10~P90)
    x_fill = [thold_values, fliplr(thold_values)];
    
    fill(x_fill, [base_p10s, fliplr(base_p90s)], colors.Baseline, 'FaceAlpha', 0.2, 'EdgeColor', 'none');
    fill(x_fill, [p10_m0, fliplr(p90_m0)], colors.M0, 'FaceAlpha', 0.2, 'EdgeColor', 'none');
    fill(x_fill, [p10_m1, fliplr(p90_m1)], colors.M1, 'FaceAlpha', 0.2, 'EdgeColor', 'none');
    fill(x_fill, [p10_m2, fliplr(p90_m2)], colors.M2, 'FaceAlpha', 0.2, 'EdgeColor', 'none');
    
    % 중앙값선 그리기
    plot(thold_values, base_meds, '-d', 'Color', colors.Baseline, 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', colors.Baseline);
    plot(thold_values, med_m0, '-o', 'Color', colors.M0, 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', colors.M0);
    plot(thold_values, med_m1, '-s', 'Color', colors.M1, 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', colors.M1);
    plot(thold_values, med_m2, '-^', 'Color', colors.M2, 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', colors.M2);
    
    hold off;
    
    xlabel('T_{hold} (ms)', 'FontSize', 11);
    ylabel('Median Delay (ms)', 'FontSize', 11);
    title(sprintf('시나리오 %s', sc), 'FontSize', 12);
    xlim([25 75]);
    set(gca, 'XTick', thold_values);
    grid on;
    
    if sc_idx == 3
        legend({'기존 방식 (P10-P90)', '기법 1 (P10-P90)', '기법 2 (P10-P90)', '기법 3 (P10-P90)', ...
                '기존 방식', '기법 1', '기법 2', '기법 3'}, ...
            'Location', 'northeast', 'FontSize', 7);
    end
end
%% 저장
saveas(figure(1), fullfile(output_dir, 'delay_boxplot_all.png'));
saveas(figure(2), fullfile(output_dir, 'delay_cdf.png'));
saveas(figure(3), fullfile(output_dir, 'delay_mean_errorbar.png'));
saveas(figure(4), fullfile(output_dir, 'delay_median_errorbar.png'));
saveas(figure(5), fullfile(output_dir, 'delay_mean_shaded.png'));
saveas(figure(6), fullfile(output_dir, 'delay_median_shaded.png'));

%% 통계 출력
fprintf('\n');
fprintf('═══════════════════════════════════════════════════════════════════════════\n');
fprintf('                    지연 통계 요약 (중위값 기준)\n');
fprintf('═══════════════════════════════════════════════════════════════════════════\n');

for sc_idx = 1:3
    sc = scenarios{sc_idx};
    fprintf('\n[시나리오 %s: %s]\n', sc, scenario_desc{sc_idx});
    
    base_d = get_all_delays(results_m0m1, sc, 0, 'Baseline', num_seeds);
    base_med = calc_median(base_d);
    
    fprintf('  %-10s: 중위값=%6.1fms, Q1=%6.1fms, Q3=%6.1fms, P10=%6.1f, P90=%6.1f\n', ...
        'Baseline', base_med, calc_quantile(base_d, 0.25), calc_quantile(base_d, 0.75), ...
        calc_quantile(base_d, 0.10), calc_quantile(base_d, 0.90));
    
    methods_list = {'M0', 'M1(5)', 'M2'};
    method_names = {'M0', 'M1', 'M2'};
    
    for m_idx = 1:3
        method = methods_list{m_idx};
        fprintf('  %s:\n', method_names{m_idx});
        
        for th = thold_values
            if strcmp(method, 'M2')
                d = get_all_delays(results_m2, sc, th, method, num_seeds);
            else
                d = get_all_delays(results_m0m1, sc, th, method, num_seeds);
            end
            
            med = calc_median(d);
            improve = (base_med - med) / base_med * 100;
            fprintf('    T%d: 중위값=%6.1fms (%.0f%% 개선), Q1=%6.1f, Q3=%6.1f\n', ...
                th, med, improve, calc_quantile(d, 0.25), calc_quantile(d, 0.75));
        end
    end
end

%% ═══════════════════════════════════════════════════════════════════════════
%  Helper Functions
%% ═══════════════════════════════════════════════════════════════════════════

function draw_boxplot(x, data, color, width)
    % 직접 구현한 boxplot
    % x: x 위치
    % data: 데이터 배열
    % color: 박스 색상
    % width: 박스 너비
    
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
    min_val = p10;  % P10 사용
    max_val = p90;  % P90 사용
    
    half_w = width / 2;
    
    % 박스 (Q1 ~ Q3)
    patch([x-half_w, x+half_w, x+half_w, x-half_w], ...
          [q1, q1, q3, q3], ...
          color, 'FaceAlpha', 0.5, 'EdgeColor', color, 'LineWidth', 1.5);
    
    % 중위값 선
    plot([x-half_w, x+half_w], [q2, q2], 'k-', 'LineWidth', 2);
    
    % 수염 (Min ~ Q1, Q3 ~ Max)
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