%% visualize_validation.m
% validation_test.csv 결과 시각화 및 분석

clear; clc;

%% 데이터 로드
csv_file = 'results/summary/validation_test.csv';
if ~exist(csv_file, 'file')
    error('CSV 파일이 없습니다: %s', csv_file);
end

data = readtable(csv_file);
fprintf('데이터 로드: %d rows x %d columns\n\n', height(data), width(data));

%% 기본 정보 출력
fprintf('═══════════════════════════════════════════════════════════════\n');
fprintf('  Validation Results Analysis\n');
fprintf('═══════════════════════════════════════════════════════════════\n\n');

fprintf('■ 실험 구성:\n');
for i = 1:height(data)
    fprintf('  [%s] Phase %d: STA=%d, rho=%.1f, T_hold=%dms\n', ...
        data.exp_id{i}, data.phase(i), data.num_stas(i), ...
        data.rho(i), data.thold_ms(i));
end

%% Figure 1: 핵심 성능 비교
figure('Name', 'Core Performance', 'Position', [100, 100, 1000, 400]);

% Delay 비교
subplot(1,3,1);
bar_colors = [0.3 0.3 0.8; 0.2 0.7 0.3; 0.8 0.4 0.2];
b = bar(data.delay_mean_ms);
b.FaceColor = 'flat';
for i = 1:height(data)
    b.CData(i,:) = bar_colors(i,:);
end
set(gca, 'XTickLabel', data.exp_id);
ylabel('Mean Delay (ms)');
title('Delay Comparison');
grid on;

% 개선율 표시
for i = 2:height(data)
    improve = (data.delay_mean_ms(1) - data.delay_mean_ms(i)) / data.delay_mean_ms(1) * 100;
    text(i, data.delay_mean_ms(i) + 5, sprintf('-%.0f%%', improve), ...
        'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'Color', 'red');
end

% Completion Rate
subplot(1,3,2);
b = bar(data.completion_rate * 100);
b.FaceColor = 'flat';
for i = 1:height(data)
    b.CData(i,:) = bar_colors(i,:);
end
set(gca, 'XTickLabel', data.exp_id);
ylabel('Completion Rate (%)');
title('Completion Rate');
ylim([0 105]);
grid on;

% 값 표시
for i = 1:height(data)
    text(i, data.completion_rate(i)*100 + 2, sprintf('%.1f%%', data.completion_rate(i)*100), ...
        'HorizontalAlignment', 'center', 'FontWeight', 'bold');
end

% Collision Rate
subplot(1,3,3);
b = bar(data.uora_collision_rate * 100);
b.FaceColor = 'flat';
for i = 1:height(data)
    b.CData(i,:) = bar_colors(i,:);
end
set(gca, 'XTickLabel', data.exp_id);
ylabel('Collision Rate (%)');
title('UORA Collision Rate');
grid on;

sgtitle('Core Performance Metrics', 'FontSize', 14, 'FontWeight', 'bold');

%% Figure 2: T_hold Trade-off 분석
figure('Name', 'T_hold Trade-off', 'Position', [100, 550, 1000, 400]);

% T_hold가 활성화된 Phase 2, 3만 추출
thold_idx = data.thold_ms > 0;
thold_data = data(thold_idx, :);

if height(thold_data) > 0
    % Hit Rate vs Expiration Rate
    subplot(1,3,1);
    exp_rate = thold_data.thold_expirations ./ thold_data.thold_activations * 100;
    bar_data = [thold_data.thold_hit_rate*100, exp_rate];
    b = bar(bar_data);
    b(1).FaceColor = [0.2 0.6 0.2];
    b(2).FaceColor = [0.8 0.4 0.2];
    set(gca, 'XTickLabel', thold_data.exp_id);
    ylabel('Rate (%)');
    title('Hit Rate vs Expiration Rate');
    legend('Hit Rate', 'Expiration Rate', 'Location', 'best');
    grid on;
    
    % T_hold 카운트
    subplot(1,3,2);
    bar_data = [thold_data.thold_hits, thold_data.thold_expirations];
    b = bar(bar_data);
    b(1).FaceColor = [0.3 0.6 0.3];
    b(2).FaceColor = [0.6 0.3 0.3];
    set(gca, 'XTickLabel', thold_data.exp_id);
    ylabel('Count');
    title('T_{hold} Results');
    legend('Hits', 'Expirations', 'Location', 'best');
    grid on;
    
    % Coverage vs Hit Rate
    subplot(1,3,3);
    yyaxis left
    bar(thold_data.thold_coverage, 0.5);
    ylabel('Coverage (%)');
    
    yyaxis right
    plot(1:height(thold_data), thold_data.thold_hit_rate*100, '-o', 'LineWidth', 2, 'MarkerSize', 10);
    ylabel('Hit Rate (%)');
    
    set(gca, 'XTickLabel', thold_data.exp_id);
    title('Coverage vs Hit Rate');
    legend('Coverage', 'Hit Rate', 'Location', 'best');
    grid on;
    
    sgtitle('T_hold Metrics', 'FontSize', 14, 'FontWeight', 'bold');
end

%% Figure 3: 공정성 지표
figure('Name', 'Fairness', 'Position', [100, 1000, 800, 350]);

subplot(1,2,1);
bar_data = [data.jain_index, data.min_max_ratio];
b = bar(bar_data);
b(1).FaceColor = [0.3 0.5 0.8];
b(2).FaceColor = [0.8 0.5 0.3];
set(gca, 'XTickLabel', data.exp_id);
ylabel('Index Value');
title('Fairness Indices');
legend('Jain Index', 'Min/Max Ratio', 'Location', 'best');
ylim([0 1.1]);
grid on;

subplot(1,2,2);
bar(data.cov);
set(gca, 'XTickLabel', data.exp_id);
ylabel('Coefficient of Variation');
title('Throughput CoV (lower = fairer)');
grid on;

sgtitle('Fairness Analysis', 'FontSize', 14, 'FontWeight', 'bold');

%% Figure 4: 지연 분해
figure('Name', 'Delay Decomposition', 'Position', [900, 100, 600, 400]);

delay_components = [data.initial_wait_ms, data.uora_contention_ms, data.sa_wait_ms];
b = bar(delay_components, 'stacked');
b(1).FaceColor = [0.4 0.6 0.8];
b(2).FaceColor = [0.8 0.4 0.4];
b(3).FaceColor = [0.4 0.8 0.4];
set(gca, 'XTickLabel', data.exp_id);
ylabel('Delay (ms)');
title('Delay Decomposition');
legend('Initial Wait', 'UORA Contention', 'SA Wait', 'Location', 'best');
grid on;

%% 결과 분석 출력
fprintf('\n');
fprintf('═══════════════════════════════════════════════════════════════\n');
fprintf('  결과 분석\n');
fprintf('═══════════════════════════════════════════════════════════════\n\n');

% Baseline vs T_hold 비교
baseline = data(data.phase == 1, :);
phase2 = data(data.phase == 2, :);
phase3 = data(data.phase == 3, :);

fprintf('■ Phase 1 → Phase 2 (Baseline → T_hold, rho=0.5)\n');
fprintf('  Delay: %.1f → %.1f ms (%.1f%% 개선)\n', ...
    baseline.delay_mean_ms, phase2.delay_mean_ms, ...
    (baseline.delay_mean_ms - phase2.delay_mean_ms) / baseline.delay_mean_ms * 100);
fprintf('  Completion: %.1f%% → %.1f%%\n', ...
    baseline.completion_rate * 100, phase2.completion_rate * 100);
fprintf('  Collision: %.1f%% → %.1f%%\n', ...
    baseline.uora_collision_rate * 100, phase2.uora_collision_rate * 100);

fprintf('\n■ T_hold Trade-off (Phase 2)\n');
fprintf('  Coverage: %.0f%%\n', phase2.thold_coverage);
fprintf('  Hit Rate: %.1f%% (%.0f hits / %.0f activations)\n', ...
    phase2.thold_hit_rate * 100, phase2.thold_hits, phase2.thold_activations);
fprintf('  Expirations: %.0f (%.1f%%)\n', ...
    phase2.thold_expirations, phase2.thold_expirations / phase2.thold_activations * 100);
fprintf('  Phantom Count: %.0f\n', phase2.thold_phantom_count);

fprintf('\n■ rho=0.5 vs rho=0.3 (Phase 2 vs Phase 3)\n');
fprintf('  Coverage: %.0f%% → %.0f%% (rho 낮으면 커버리지 감소)\n', ...
    phase2.thold_coverage, phase3.thold_coverage);
fprintf('  Hit Rate: %.1f%% → %.1f%%\n', ...
    phase2.thold_hit_rate * 100, phase3.thold_hit_rate * 100);
fprintf('  Expirations: %.0f → %.0f\n', ...
    phase2.thold_expirations, phase3.thold_expirations);

fprintf('\n■ 공정성 분석\n');
fprintf('  Jain Index: %.4f → %.4f (1에 가까울수록 공정)\n', ...
    baseline.jain_index, phase2.jain_index);
fprintf('  Min/Max Ratio: %.4f → %.4f (높을수록 공정)\n', ...
    baseline.min_max_ratio, phase2.min_max_ratio);

fprintf('\n');
fprintf('═══════════════════════════════════════════════════════════════\n');
fprintf('  핵심 발견\n');
fprintf('═══════════════════════════════════════════════════════════════\n');
fprintf('\n');
fprintf('  ✓ T_hold가 Delay를 86%% 개선 (103.6ms → 14.4ms)\n');
fprintf('  ✓ Completion 유지 (97.5%% → 99.9%%)\n');
fprintf('  ✓ Hit Rate %.1f%% - T_hold 시작하면 대부분 성공\n', phase2.thold_hit_rate * 100);
fprintf('\n');
fprintf('  - Phantom %d건 - 남는 SA-RU 활용 (다른 STA 피해 없음)\n', phase2.thold_phantom_count);
fprintf('  - Expirations %d건 (%.1f%%) - T_hold 만료 후 RA 전환\n', ...
    phase2.thold_expirations, phase2.thold_expirations / phase2.thold_activations * 100);
fprintf('\n');
fprintf('  → Coverage 낮으면 (rho=0.3, 43%%) Hit Rate 떨어짐 (%.1f%%)\n', phase3.thold_hit_rate * 100);
fprintf('\n');

%% 그래프 저장
if ~exist('results/figures', 'dir')
    mkdir('results/figures');
end

saveas(1, 'results/figures/validation_core_performance.png');
saveas(2, 'results/figures/validation_thold_tradeoff.png');
saveas(3, 'results/figures/validation_fairness.png');
saveas(4, 'results/figures/validation_delay_decomp.png');

fprintf('그래프 저장 완료: results/figures/\n');