%% analyze_thold_cases.m
% T_hold Case 정의 기반 분석
%
% Case 정의 (발생 시점에 따른 분류):
%   - Hit: SA-RU 할당 시점에 버퍼에 데이터 있음 → 전송 성공, T_hold 종료
%   - Phantom: SA-RU 할당 시점에 버퍼 비어 있음 → SA-RU 낭비, T_hold 유지
%   - Clean Expiration: T_hold 만료 시점에 버퍼 비어 있음 → RA 모드 전환
%   - Expiration with Data: T_hold 만료 시점에 버퍼에 패킷 있음 → RA 모드 전환
%
% 통계 관계:
%   - Activations = Hits + Expirations
%   - Expirations = Clean Expirations + Expiration with Data
%   - Phantom = 별도 카운트 (중간 이벤트, 여러 번 발생 가능)

clear; clc;
fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════════╗\n');
fprintf('║            T_hold Case 분석 (랩미팅 자료용)                       ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════╝\n\n');

%% 데이터 로드
fprintf('[데이터 로드]\n');

% 결과 파일 경로 (필요시 수정)
m0m1_file = 'results/main_m0_m1/results.mat';
m2_file = 'results/main_m2/results.mat';

if exist(m0m1_file, 'file')
    load(m0m1_file, 'results'); results_m0m1 = results;
    fprintf('  ✓ M0/M1 결과 로드\n');
else
    error('M0/M1 결과 파일 없음: %s', m0m1_file);
end

if exist(m2_file, 'file')
    load(m2_file, 'results'); results_m2 = results;
    fprintf('  ✓ M2 결과 로드\n');
else
    warning('M2 결과 파일 없음 (M0/M1만 분석)');
    results_m2 = [];
end

%% 설정
scenario_names = {'A', 'B', 'C'};
scenario_desc = {'VoIP-like', 'Video-like', 'IoT-like'};
thold_values = [30, 50, 70];
num_seeds = 3;

colors.M0 = [0.2 0.4 0.8];
colors.M1_5 = [0.9 0.6 0.1];
colors.M2 = [0.2 0.7 0.3];

output_dir = 'results/figures_cases';
if ~exist(output_dir, 'dir'), mkdir(output_dir); end

%% ═══════════════════════════════════════════════════════════════════════
%  Figure 1: Case 분포 - Stacked Bar (Hits vs Clean Exp vs Exp with Data)
%  ═══════════════════════════════════════════════════════════════════════
figure('Name', 'T_hold Case Distribution', 'Position', [100 100 1400 500]);

for sc_idx = 1:3
    sc = scenario_names{sc_idx};
    subplot(1, 3, sc_idx);
    
    % 각 T_hold 값에 대해 M0 데이터 수집
    case_data = zeros(length(thold_values), 3);  % [Hits, Clean_Exp, Exp_with_Data]
    
    for th_idx = 1:length(thold_values)
        th = thold_values(th_idx);
        
        hits_arr = []; clean_exp_arr = []; exp_data_arr = [];
        
        for s = 1:num_seeds
            field_name = sprintf('%s_T%d_M0_s%d', sc, th, s);
            if isfield(results_m0m1.runs, field_name)
                r = results_m0m1.runs.(field_name);
                if isfield(r, 'thold')
                    hits_arr(end+1) = r.thold.hits;
                    clean_exp_arr(end+1) = r.thold.clean_exp;
                    exp_data_arr(end+1) = r.thold.exp_with_data;
                end
            end
        end
        
        case_data(th_idx, 1) = mean(hits_arr);
        case_data(th_idx, 2) = mean(clean_exp_arr);
        case_data(th_idx, 3) = mean(exp_data_arr);
    end
    
    b = bar(case_data, 'stacked');
    b(1).FaceColor = [0.4 0.8 0.4];  % Hit - 초록
    b(2).FaceColor = [0.8 0.4 0.4];  % Clean Exp - 빨강
    b(3).FaceColor = [0.9 0.7 0.3];  % Exp with Data - 주황
    
    set(gca, 'XTickLabel', arrayfun(@(x) sprintf('%dms', x), thold_values, 'UniformOutput', false));
    xlabel('T_{hold}'); ylabel('Count');
    title(sprintf('%s (%s) - M0', sc, scenario_desc{sc_idx}));
    
    if sc_idx == 1
        legend({'Hit (성공)', 'Clean Exp (패킷 안옴)', 'Exp with Data (SA 못받음)'}, ...
            'Location', 'northoutside', 'Orientation', 'horizontal');
    end
    grid on;
end
sgtitle('Figure 1: T_hold Activation 결과 분포 (Activations = Hits + Expirations)');

saveas(gcf, fullfile(output_dir, 'case_distribution.png'));

%% ═══════════════════════════════════════════════════════════════════════
%  Figure 2: Phantom vs Activation 비율 (Phantom per Activation)
%  ═══════════════════════════════════════════════════════════════════════
figure('Name', 'Phantom Analysis', 'Position', [100 100 1400 450]);

for sc_idx = 1:3
    sc = scenario_names{sc_idx};
    
    % Subplot 1: Phantom Count 추이
    subplot(2, 3, sc_idx);
    
    m0_ph = zeros(1,3); m1_ph = zeros(1,3);
    for th_idx = 1:length(thold_values)
        th = thold_values(th_idx);
        [m0_ph(th_idx), ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'thold.phantoms', num_seeds);
        [m1_ph(th_idx), ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'thold.phantoms', num_seeds);
    end
    
    plot(thold_values, m0_ph, '-o', 'Color', colors.M0, 'LineWidth', 2, 'MarkerFaceColor', colors.M0);
    hold on;
    plot(thold_values, m1_ph, '-s', 'Color', colors.M1_5, 'LineWidth', 2, 'MarkerFaceColor', colors.M1_5);
    hold off;
    
    xlabel('T_{hold} (ms)'); ylabel('Phantom Count');
    title(sprintf('%s - Phantom Count', sc));
    if sc_idx == 1, legend({'M0', 'M1(5)'}, 'Location', 'best'); end
    xlim([25 75]); grid on;
    
    % Subplot 2: Phantom per Activation
    subplot(2, 3, sc_idx + 3);
    
    m0_ppa = zeros(1,3); m1_ppa = zeros(1,3);
    for th_idx = 1:length(thold_values)
        th = thold_values(th_idx);
        [m0_ppa(th_idx), ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'thold.phantom_per_activation', num_seeds);
        [m1_ppa(th_idx), ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'thold.phantom_per_activation', num_seeds);
    end
    
    plot(thold_values, m0_ppa, '-o', 'Color', colors.M0, 'LineWidth', 2, 'MarkerFaceColor', colors.M0);
    hold on;
    plot(thold_values, m1_ppa, '-s', 'Color', colors.M1_5, 'LineWidth', 2, 'MarkerFaceColor', colors.M1_5);
    hold off;
    
    xlabel('T_{hold} (ms)'); ylabel('Phantom / Activation');
    title(sprintf('%s - Phantom per Activation', sc));
    xlim([25 75]); grid on;
end
sgtitle('Figure 2: Phantom 분석 (SA-RU 할당 시점에 버퍼 비어있음)');

saveas(gcf, fullfile(output_dir, 'phantom_analysis.png'));

%% ═══════════════════════════════════════════════════════════════════════
%  Figure 3: Expiration 세부 분석 (Clean vs with Data)
%  ═══════════════════════════════════════════════════════════════════════
figure('Name', 'Expiration Analysis', 'Position', [100 100 1400 450]);

for sc_idx = 1:3
    sc = scenario_names{sc_idx};
    
    % Subplot 1: Clean Expiration 비율
    subplot(2, 3, sc_idx);
    
    m0_clean_ratio = zeros(1,3); m1_clean_ratio = zeros(1,3);
    for th_idx = 1:length(thold_values)
        th = thold_values(th_idx);
        
        % M0
        [clean, ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'thold.clean_exp', num_seeds);
        [total_exp, ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'thold.expirations', num_seeds);
        m0_clean_ratio(th_idx) = clean / max(total_exp, 1) * 100;
        
        % M1(5)
        [clean, ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'thold.clean_exp', num_seeds);
        [total_exp, ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'thold.expirations', num_seeds);
        m1_clean_ratio(th_idx) = clean / max(total_exp, 1) * 100;
    end
    
    plot(thold_values, m0_clean_ratio, '-o', 'Color', colors.M0, 'LineWidth', 2, 'MarkerFaceColor', colors.M0);
    hold on;
    plot(thold_values, m1_clean_ratio, '-s', 'Color', colors.M1_5, 'LineWidth', 2, 'MarkerFaceColor', colors.M1_5);
    hold off;
    
    xlabel('T_{hold} (ms)'); ylabel('Clean Exp / Total Exp (%)');
    title(sprintf('%s - Clean Expiration 비율', sc));
    if sc_idx == 1, legend({'M0', 'M1(5)'}, 'Location', 'best'); end
    xlim([25 75]); ylim([0 100]); grid on;
    
    % Subplot 2: Expiration with Data Count
    subplot(2, 3, sc_idx + 3);
    
    m0_exp_data = zeros(1,3); m1_exp_data = zeros(1,3);
    for th_idx = 1:length(thold_values)
        th = thold_values(th_idx);
        [m0_exp_data(th_idx), ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'thold.exp_with_data', num_seeds);
        [m1_exp_data(th_idx), ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'thold.exp_with_data', num_seeds);
    end
    
    plot(thold_values, m0_exp_data, '-o', 'Color', colors.M0, 'LineWidth', 2, 'MarkerFaceColor', colors.M0);
    hold on;
    plot(thold_values, m1_exp_data, '-s', 'Color', colors.M1_5, 'LineWidth', 2, 'MarkerFaceColor', colors.M1_5);
    hold off;
    
    xlabel('T_{hold} (ms)'); ylabel('Exp with Data Count');
    title(sprintf('%s - Expiration with Data', sc));
    xlim([25 75]); grid on;
end
sgtitle('Figure 3: Expiration 세부 분석 (T_hold 만료 시점 버퍼 상태)');

saveas(gcf, fullfile(output_dir, 'expiration_analysis.png'));

%% ═══════════════════════════════════════════════════════════════════════
%  Figure 4: 전체 Case 요약 테이블 출력
%  ═══════════════════════════════════════════════════════════════════════
fprintf('\n');
fprintf('╔═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗\n');
fprintf('║                                T_hold Case 분석 결과 요약 (M0, 3회 평균)                                                    ║\n');
fprintf('╚═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝\n\n');

for sc_idx = 1:length(scenario_names)
    sc = scenario_names{sc_idx};
    
    fprintf('[시나리오 %s: %s]\n', sc, scenario_desc{sc_idx});
    fprintf('┌──────────┬────────────┬──────────┬──────────┬──────────┬──────────┬──────────┬────────────┐\n');
    fprintf('│ T_hold   │ Activations│ Hits     │ Phantoms │ Total Exp│ Clean Exp│ Exp+Data │ Hit Rate   │\n');
    fprintf('├──────────┼────────────┼──────────┼──────────┼──────────┼──────────┼──────────┼────────────┤\n');
    
    for th_idx = 1:length(thold_values)
        th = thold_values(th_idx);
        
        [act, ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'thold.activations', num_seeds);
        [hits, ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'thold.hits', num_seeds);
        [ph, ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'thold.phantoms', num_seeds);
        [exp, ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'thold.expirations', num_seeds);
        [clean, ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'thold.clean_exp', num_seeds);
        [exp_d, ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'thold.exp_with_data', num_seeds);
        [hr, ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'thold.hit_rate', num_seeds);
        
        fprintf('│ %4dms   │ %10.0f │ %8.0f │ %8.0f │ %8.0f │ %8.0f │ %8.0f │ %8.1f%%  │\n', ...
            th, act, hits, ph, exp, clean, exp_d, hr*100);
    end
    
    fprintf('└──────────┴────────────┴──────────┴──────────┴──────────┴──────────┴──────────┴────────────┘\n');
    
    % 통계 검증
    fprintf('  [검증] Activations ≈ Hits + Expirations: ');
    [act, ~] = get_metric_avg(results_m0m1, sc, 50, 'M0', 'thold.activations', num_seeds);
    [hits, ~] = get_metric_avg(results_m0m1, sc, 50, 'M0', 'thold.hits', num_seeds);
    [exp, ~] = get_metric_avg(results_m0m1, sc, 50, 'M0', 'thold.expirations', num_seeds);
    if abs(act - (hits + exp)) < 1
        fprintf('✓ (%.0f = %.0f + %.0f)\n', act, hits, exp);
    else
        fprintf('⚠️ 불일치! (%.0f ≠ %.0f + %.0f)\n', act, hits, exp);
    end
    
    fprintf('  [검증] Expirations = Clean + Exp_with_Data: ');
    [clean, ~] = get_metric_avg(results_m0m1, sc, 50, 'M0', 'thold.clean_exp', num_seeds);
    [exp_d, ~] = get_metric_avg(results_m0m1, sc, 50, 'M0', 'thold.exp_with_data', num_seeds);
    if abs(exp - (clean + exp_d)) < 1
        fprintf('✓ (%.0f = %.0f + %.0f)\n', exp, clean, exp_d);
    else
        fprintf('⚠️ 불일치! (%.0f ≠ %.0f + %.0f)\n', exp, clean, exp_d);
    end
    
    fprintf('\n');
end

%% ═══════════════════════════════════════════════════════════════════════
%  Figure 5: Phantom vs Expiration 차이 시각화 (표에서 그림 참고용)
%  ═══════════════════════════════════════════════════════════════════════
figure('Name', 'Phantom vs Expiration 차이', 'Position', [100 100 800 600]);

% 개념도 텍스트로 표시
text(0.5, 0.95, 'Phantom vs Expiration 차이', 'FontSize', 14, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');

text(0.1, 0.8, '■ Phantom', 'FontSize', 12, 'FontWeight', 'bold', 'Color', [0.8 0.4 0.4]);
text(0.15, 0.75, '- 발생 시점: SA-RU 할당 시', 'FontSize', 10);
text(0.15, 0.70, '- T_hold 상태: 유지 (다음 TF에서 재시도)', 'FontSize', 10);
text(0.15, 0.65, '- 발생 횟수: 여러 번 가능', 'FontSize', 10);
text(0.15, 0.60, '- 의미: SA-RU 낭비 횟수', 'FontSize', 10);

text(0.55, 0.8, '■ Expiration', 'FontSize', 12, 'FontWeight', 'bold', 'Color', [0.4 0.4 0.8]);
text(0.6, 0.75, '- 발생 시점: T_hold 만료 시', 'FontSize', 10);
text(0.6, 0.70, '- T_hold 상태: 종료', 'FontSize', 10);
text(0.6, 0.65, '- 발생 횟수: 1회 (종료 이벤트)', 'FontSize', 10);
text(0.6, 0.60, '- 의미: T_hold 최종 결과', 'FontSize', 10);

text(0.1, 0.45, '■ Clean Expiration', 'FontSize', 11, 'Color', [0.8 0.4 0.4]);
text(0.15, 0.40, '버퍼 비어있음 → 패킷이 안 옴 (예측 실패)', 'FontSize', 10);

text(0.1, 0.30, '■ Expiration with Data', 'FontSize', 11, 'Color', [0.9 0.7 0.3]);
text(0.15, 0.25, '버퍼에 데이터 있음 → SA 할당 못 받음 (스케줄링 실패)', 'FontSize', 10);

text(0.1, 0.12, '통계 관계:', 'FontSize', 11, 'FontWeight', 'bold');
text(0.15, 0.07, 'Activations = Hits + Expirations', 'FontSize', 10, 'FontName', 'FixedWidth');
text(0.15, 0.02, 'Expirations = Clean_Exp + Exp_with_Data', 'FontSize', 10, 'FontName', 'FixedWidth');

axis off;
saveas(gcf, fullfile(output_dir, 'case_definition.png'));

fprintf('\n[완료] 분석 결과 저장: %s/\n', output_dir);

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