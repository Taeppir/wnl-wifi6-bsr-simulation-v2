%% analyze_exp2.m
% 추가 실험 2: 제안 기법의 한계 분석
%
% 시나리오:
%   E: 긴 On 구간 (ρ=0.70, μ_on=117ms) → T_hold 발동 빈도 감소
%   F: 고부하 + burst (λ=400, ρ=0.30) → 고부하에서 T_hold 한계
%   G: Poisson 트래픽 → On/Off 패턴 없을 때 효과
%
% 방법: Baseline, M2 (T_hold=50ms)

clear; clc;
fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗\n');
fprintf('║                          추가 실험 2: 제안 기법의 한계 분석                                                       ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝\n\n');

%% ═══════════════════════════════════════════════════════════════════════════
%  데이터 로드
%  ═══════════════════════════════════════════════════════════════════════════
fprintf('[데이터 로드]\n');

result_file = 'results/additional_exp2/results.mat';
if ~exist(result_file, 'file')
    error('결과 파일 없음: %s', result_file);
end

load(result_file, 'results');
fprintf('  ✓ 결과 로드: %s\n', result_file);

% 필드 이름 확인
run_names = fieldnames(results.runs);
fprintf('  ✓ 총 %d개 runs 발견\n', length(run_names));

%% ═══════════════════════════════════════════════════════════════════════════
%  설정
%  ═══════════════════════════════════════════════════════════════════════════
scenario_keys = {'E', 'F', 'G'};
scenario_labels = {'E', 'F', 'G'};
scenario_desc = {
    'Long On (ρ=0.70, μ_{on}=117ms)', 
    'High Load + Burst (λ=400, ρ=0.30)', 
    'Poisson Traffic'
};
scenario_expected = {
    'T_hold 발동 빈도 감소',
    '고부하에서 T_hold 한계',
    'On/Off 패턴 없을 때 효과'
};
methods = {'Baseline', 'M2'};
num_seeds = 3;
num_scenarios = 3;

% 색상
colors.Baseline = [0.5 0.5 0.5];           % 회색
colors.M2 = [0.466 0.674 0.188];           % 녹색

output_dir = 'results/figures_exp2';
if ~exist(output_dir, 'dir'), mkdir(output_dir); end

%% ═══════════════════════════════════════════════════════════════════════════
%  PART 1: 시나리오 파라미터 요약
%  ═══════════════════════════════════════════════════════════════════════════
fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗\n');
fprintf('║                                         시나리오 파라미터                                                        ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝\n\n');

fprintf('┌────────┬─────────────────┬───────┬─────────┬────────┬────────────┬──────────┐\n');
fprintf('│ 시나리오 │ 특성             │  ρ    │ μ_on    │   λ    │ 전체 부하   │ 용량 대비 │\n');
fprintf('├────────┼─────────────────┼───────┼─────────┼────────┼────────────┼──────────┤\n');
fprintf('│   E    │ Long On         │ 0.70  │  117ms  │  100   │ 1400 pkt/s │   49%%    │\n');
fprintf('│   F    │ High Load+Burst │ 0.30  │   21ms  │  400   │ 2400 pkt/s │   83%%    │\n');
fprintf('│   G    │ Poisson         │   -   │    -    │  100   │ 2000 pkt/s │   69%%    │\n');
fprintf('└────────┴─────────────────┴───────┴─────────┴────────┴────────────┴──────────┘\n\n');

fprintf('■ 예상 동작:\n');
for i = 1:num_scenarios
    fprintf('  %s: %s → %s\n', scenario_keys{i}, scenario_desc{i}, scenario_expected{i});
end
fprintf('\n');

%% ═══════════════════════════════════════════════════════════════════════════
%  데이터 수집
%  ═══════════════════════════════════════════════════════════════════════════

% 데이터 구조체 초기화
data = struct();

for sc_idx = 1:num_scenarios
    sc_key = scenario_keys{sc_idx};
    
    for m_idx = 1:length(methods)
        method = methods{m_idx};
        
        % 각 시드별 데이터 수집
        delays = [];
        stds = [];
        p10s = [];
        p50s = [];
        p90s = [];
        counts = [];
        
        % T_hold 관련
        activations = [];
        hits = [];
        phantoms = [];
        hit_rates = [];
        
        % UORA 관련
        uora_success = [];
        uora_collision = [];
        
        % Throughput & Packet 관련
        throughputs = [];
        pkt_generated = [];
        pkt_completed = [];
        
        for s = 1:num_seeds
            field_name = sprintf('%s_%s_s%d', sc_key, method, s);
            
            if isfield(results.runs, field_name)
                r = results.runs.(field_name);
                
                % 지연 통계
                if isfield(r, 'delay')
                    if isfield(r.delay, 'mean_ms'), delays(end+1) = r.delay.mean_ms; end
                    if isfield(r.delay, 'std_ms'), stds(end+1) = r.delay.std_ms; end
                    if isfield(r.delay, 'p10_ms'), p10s(end+1) = r.delay.p10_ms; end
                    if isfield(r.delay, 'p50_ms'), p50s(end+1) = r.delay.p50_ms; end
                    if isfield(r.delay, 'p90_ms'), p90s(end+1) = r.delay.p90_ms; end
                end
                
                % 패킷 수
                if isfield(r, 'packets') && isfield(r.packets, 'completed')
                    counts(end+1) = r.packets.completed;
                end
                
                % T_hold 통계
                if isfield(r, 'thold')
                    if isfield(r.thold, 'activations'), activations(end+1) = r.thold.activations; end
                    if isfield(r.thold, 'hits'), hits(end+1) = r.thold.hits; end
                    if isfield(r.thold, 'phantoms'), phantoms(end+1) = r.thold.phantoms; end
                    if isfield(r.thold, 'hit_rate'), hit_rates(end+1) = r.thold.hit_rate; end
                end
                
                % UORA 통계
                if isfield(r, 'uora')
                    if isfield(r.uora, 'total_success'), uora_success(end+1) = r.uora.total_success; end
                    if isfield(r.uora, 'total_collision'), uora_collision(end+1) = r.uora.total_collision; end
                end
                
                % Throughput 통계
                if isfield(r, 'throughput') && isfield(r.throughput, 'total_mbps')
                    throughputs(end+1) = r.throughput.total_mbps;
                end
                
                % Packet 통계
                if isfield(r, 'packets')
                    if isfield(r.packets, 'generated'), pkt_generated(end+1) = r.packets.generated; end
                    if isfield(r.packets, 'completed'), pkt_completed(end+1) = r.packets.completed; end
                end
            end
        end
        
        % 평균 저장 (빈 배열 처리)
        if isempty(delays), delays = NaN; end
        if isempty(stds), stds = NaN; end
        if isempty(p10s), p10s = NaN; end
        if isempty(p50s), p50s = NaN; end
        if isempty(p90s), p90s = NaN; end
        if isempty(counts), counts = NaN; end
        if isempty(activations), activations = NaN; end
        if isempty(hits), hits = NaN; end
        if isempty(phantoms), phantoms = NaN; end
        if isempty(hit_rates), hit_rates = NaN; end
        if isempty(uora_success), uora_success = NaN; end
        if isempty(uora_collision), uora_collision = NaN; end
        if isempty(throughputs), throughputs = NaN; end
        if isempty(pkt_generated), pkt_generated = NaN; end
        if isempty(pkt_completed), pkt_completed = NaN; end
        
        data.(sc_key).(method).delay_mean = mean(delays);
        data.(sc_key).(method).delay_mean_std = std(delays);
        data.(sc_key).(method).delay_std = mean(stds);
        data.(sc_key).(method).p10 = mean(p10s);
        data.(sc_key).(method).p50 = mean(p50s);
        data.(sc_key).(method).p90 = mean(p90s);
        data.(sc_key).(method).count = mean(counts);
        
        data.(sc_key).(method).activations = mean(activations);
        data.(sc_key).(method).hits = mean(hits);
        data.(sc_key).(method).phantoms = mean(phantoms);
        data.(sc_key).(method).hit_rate = mean(hit_rates);
        
        data.(sc_key).(method).uora_success = mean(uora_success);
        data.(sc_key).(method).uora_collision = mean(uora_collision);
        
        data.(sc_key).(method).throughput = mean(throughputs);
        data.(sc_key).(method).pkt_generated = mean(pkt_generated);
        data.(sc_key).(method).pkt_completed = mean(pkt_completed);
        if ~isnan(mean(pkt_generated)) && ~isnan(mean(pkt_completed)) && mean(pkt_generated) > 0
            data.(sc_key).(method).completion_rate = mean(pkt_completed) / mean(pkt_generated) * 100;
        else
            data.(sc_key).(method).completion_rate = NaN;
        end
    end
end

%% ═══════════════════════════════════════════════════════════════════════════
%  PART 2: 지연 상세 통계
%  ═══════════════════════════════════════════════════════════════════════════
fprintf('╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗\n');
fprintf('║                                         지연 상세 통계                                                           ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝\n\n');

fprintf('┌──────────┬──────────┬────────────┬────────────┬────────────┬────────────┬────────────┬────────────┬────────────┐\n');
fprintf('│ 시나리오  │ Method   │ Mean (ms)  │ Std (ms)   │ P10 (ms)   │ P50 (ms)   │ P90 (ms)   │ Count      │ 개선율     │\n');
fprintf('├──────────┼──────────┼────────────┼────────────┼────────────┼────────────┼────────────┼────────────┼────────────┤\n');

for sc_idx = 1:num_scenarios
    sc_key = scenario_keys{sc_idx};
    sc_label = scenario_labels{sc_idx};
    
    base_mean = data.(sc_key).Baseline.delay_mean;
    
    for m_idx = 1:length(methods)
        method = methods{m_idx};
        d = data.(sc_key).(method);
        
        if strcmp(method, 'Baseline')
            fprintf('│    %s     │ %-8s │ %7.1f±%.1f│ %10.1f │ %10.1f │ %10.1f │ %10.1f │ %10.0f │     -      │\n', ...
                sc_label, method, d.delay_mean, d.delay_mean_std, d.delay_std, d.p10, d.p50, d.p90, d.count);
        else
            if ~isnan(base_mean) && base_mean > 0
                improvement = (base_mean - d.delay_mean) / base_mean * 100;
            else
                improvement = NaN;
            end
            fprintf('│    %s     │ %-8s │ %7.1f±%.1f│ %10.1f │ %10.1f │ %10.1f │ %10.1f │ %10.0f │ %+6.1f%%    │\n', ...
                sc_label, method, d.delay_mean, d.delay_mean_std, d.delay_std, d.p10, d.p50, d.p90, d.count, improvement);
        end
    end
    
    if sc_idx < num_scenarios
        fprintf('├──────────┼──────────┼────────────┼────────────┼────────────┼────────────┼────────────┼────────────┼────────────┤\n');
    end
end
fprintf('└──────────┴──────────┴────────────┴────────────┴────────────┴────────────┴────────────┴────────────┴────────────┘\n\n');

%% ═══════════════════════════════════════════════════════════════════════════
%  PART 3: M2 T_hold 상세 통계
%  ═══════════════════════════════════════════════════════════════════════════
fprintf('╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗\n');
fprintf('║                                       M2 T_hold 상세 통계                                                        ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝\n\n');

fprintf('┌──────────┬────────────┬────────────┬────────────┬────────────┐\n');
fprintf('│ 시나리오  │ Activations│    Hits    │  Phantoms  │  Hit Rate  │\n');
fprintf('├──────────┼────────────┼────────────┼────────────┼────────────┤\n');

for sc_idx = 1:num_scenarios
    sc_key = scenario_keys{sc_idx};
    sc_label = scenario_labels{sc_idx};
    d = data.(sc_key).M2;
    
    hr = d.hit_rate;
    if ~isnan(hr)
        hr = hr * 100;
    end
    
    % NaN 처리
    act_str = 'N/A';
    hits_str = 'N/A';
    phan_str = 'N/A';
    hr_str = 'N/A';
    
    if ~isnan(d.activations), act_str = sprintf('%10.0f', d.activations); end
    if ~isnan(d.hits), hits_str = sprintf('%10.0f', d.hits); end
    if ~isnan(d.phantoms), phan_str = sprintf('%10.0f', d.phantoms); end
    if ~isnan(hr), hr_str = sprintf('%8.1f%%', hr); end
    
    fprintf('│    %s     │ %10s │ %10s │ %10s │ %10s │\n', ...
        sc_label, act_str, hits_str, phan_str, hr_str);
end
fprintf('└──────────┴────────────┴────────────┴────────────┴────────────┘\n\n');

%% ═══════════════════════════════════════════════════════════════════════════
%  PART 4: UORA 상세 통계
%  ═══════════════════════════════════════════════════════════════════════════
fprintf('╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗\n');
fprintf('║                                         UORA 상세 통계                                                           ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝\n\n');

fprintf('┌──────────┬──────────┬────────────┬────────────┬────────────┬────────────┐\n');
fprintf('│ 시나리오  │ Method   │ Attempts   │ Successes  │ Collisions │ Coll Rate  │\n');
fprintf('├──────────┼──────────┼────────────┼────────────┼────────────┼────────────┤\n');

for sc_idx = 1:num_scenarios
    sc_key = scenario_keys{sc_idx};
    sc_label = scenario_labels{sc_idx};
    
    for m_idx = 1:length(methods)
        method = methods{m_idx};
        d = data.(sc_key).(method);
        
        attempts = d.uora_success + d.uora_collision;
        if attempts > 0 && ~isnan(attempts)
            coll_rate = d.uora_collision / attempts * 100;
        else
            coll_rate = NaN;
        end
        
        fprintf('│    %s     │ %-8s │ %10.0f │ %10.0f │ %10.0f │ %8.1f%%  │\n', ...
            sc_label, method, attempts, d.uora_success, d.uora_collision, coll_rate);
    end
    
    if sc_idx < num_scenarios
        fprintf('├──────────┼──────────┼────────────┼────────────┼────────────┼────────────┤\n');
    end
end
fprintf('└──────────┴──────────┴────────────┴────────────┴────────────┴────────────┘\n\n');

%% ═══════════════════════════════════════════════════════════════════════════
%  PART 5: Throughput & Packet 통계
%  ═══════════════════════════════════════════════════════════════════════════
fprintf('╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗\n');
fprintf('║                                     Throughput & Packet 통계                                                     ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝\n\n');

fprintf('┌──────────┬──────────┬────────────┬────────────┬────────────┬────────────┐\n');
fprintf('│ 시나리오  │ Method   │ Throughput │ Generated  │ Completed  │ Comp Rate  │\n');
fprintf('│          │          │ (Mbps)     │            │            │            │\n');
fprintf('├──────────┼──────────┼────────────┼────────────┼────────────┼────────────┤\n');

for sc_idx = 1:num_scenarios
    sc_key = scenario_keys{sc_idx};
    sc_label = scenario_labels{sc_idx};
    
    for m_idx = 1:length(methods)
        method = methods{m_idx};
        d = data.(sc_key).(method);
        
        fprintf('│    %s     │ %-8s │ %10.2f │ %10.0f │ %10.0f │ %8.1f%%  │\n', ...
            sc_label, method, d.throughput, d.pkt_generated, d.pkt_completed, d.completion_rate);
    end
    
    if sc_idx < num_scenarios
        fprintf('├──────────┼──────────┼────────────┼────────────┼────────────┼────────────┤\n');
    end
end
fprintf('└──────────┴──────────┴────────────┴────────────┴────────────┴────────────┘\n\n');

%% ═══════════════════════════════════════════════════════════════════════════
%  PART 6: 한계 분석
%  ═══════════════════════════════════════════════════════════════════════════
fprintf('╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗\n');
fprintf('║                                         한계 분석                                                                ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝\n\n');

fprintf('■ 시나리오별 M2 효과 분석\n');
fprintf('┌────────┬─────────────────────────────────────────────────────────────────────────────────────────────┐\n');
fprintf('│ 시나리오 │ 분석                                                                                        │\n');
fprintf('├────────┼─────────────────────────────────────────────────────────────────────────────────────────────┤\n');

for sc_idx = 1:num_scenarios
    sc_key = scenario_keys{sc_idx};
    base_d = data.(sc_key).Baseline.delay_mean;
    m2_d = data.(sc_key).M2.delay_mean;
    
    if ~isnan(base_d) && ~isnan(m2_d) && base_d > 0
        improvement = (base_d - m2_d) / base_d * 100;
        
        if improvement > 50
            verdict = '효과 우수';
        elseif improvement > 20
            verdict = '효과 양호';
        elseif improvement > 0
            verdict = '효과 미미';
        else
            verdict = '효과 없음 또는 악화';
        end
        
        fprintf('│   %s    │ 개선율 %+.1f%% (%s) - %s                                            │\n', ...
            sc_key, improvement, verdict, scenario_expected{sc_idx});
    else
        fprintf('│   %s    │ 데이터 불충분                                                                            │\n', sc_key);
    end
end
fprintf('└────────┴─────────────────────────────────────────────────────────────────────────────────────────────┘\n\n');

%% ═══════════════════════════════════════════════════════════════════════════
%  Figure 생성
%  ═══════════════════════════════════════════════════════════════════════════
fprintf('╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗\n');
fprintf('║                                           Figure 생성                                                            ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝\n\n');

%% Figure 1: Delay CDF (1x3 grid)
figure('Name', 'Fig 1: Delay CDF', 'Position', [100 100 1400 400]);

for sc_idx = 1:num_scenarios
    sc_key = scenario_keys{sc_idx};
    sc_label = scenario_labels{sc_idx};
    subplot(1, 3, sc_idx);
    
    hold on;
    
    % Baseline
    delays_base = [];
    for s = 1:num_seeds
        field_name = sprintf('%s_Baseline_s%d', sc_key, s);
        if isfield(results.runs, field_name)
            r = results.runs.(field_name);
            if isfield(r, 'delay')
                if isfield(r.delay, 'all_ms')
                    delays_base = [delays_base; r.delay.all_ms(:)];
                elseif isfield(r.delay, 'all_delays_ms')
                    delays_base = [delays_base; r.delay.all_delays_ms(:)];
                end
            end
        end
    end
    if ~isempty(delays_base)
        % 수동 CDF 계산
        x_base = sort(delays_base);
        f_base = (1:length(x_base))' / length(x_base);
        plot(x_base, f_base, '-', 'Color', colors.Baseline, 'LineWidth', 2, 'DisplayName', 'Baseline');
    end
    
    % M2
    delays_m2 = [];
    for s = 1:num_seeds
        field_name = sprintf('%s_M2_s%d', sc_key, s);
        if isfield(results.runs, field_name)
            r = results.runs.(field_name);
            if isfield(r, 'delay')
                if isfield(r.delay, 'all_ms')
                    delays_m2 = [delays_m2; r.delay.all_ms(:)];
                elseif isfield(r.delay, 'all_delays_ms')
                    delays_m2 = [delays_m2; r.delay.all_delays_ms(:)];
                end
            end
        end
    end
    if ~isempty(delays_m2)
        % 수동 CDF 계산
        x_m2 = sort(delays_m2);
        f_m2 = (1:length(x_m2))' / length(x_m2);
        plot(x_m2, f_m2, '-', 'Color', colors.M2, 'LineWidth', 2, 'DisplayName', 'M2');
    end
    
    % Reference lines
    yline(0.5, ':', 'P50', 'Color', [0.6 0.6 0.6]);
    yline(0.9, ':', 'P90', 'Color', [0.6 0.6 0.6]);
    
    hold off;
    xlabel('Delay (ms)');
    ylabel('CDF');
    title(sprintf('%s: %s', sc_label, scenario_desc{sc_idx}));
    legend('Location', 'southeast');
    grid on;
    
    all_delays = [delays_base; delays_m2];
    if ~isempty(all_delays)
        xlim([0 min(500, prctile(all_delays, 99)*1.2)]);
    end
end
sgtitle('Figure 1: Delay CDF', 'FontSize', 14, 'FontWeight', 'bold');
saveas(gcf, fullfile(output_dir, 'fig01_delay_cdf.png'));
fprintf('  ✓ Figure 1: Delay CDF 저장\n');

%% Figure 2: Mean Delay 비교
figure('Name', 'Fig 2: Mean Delay', 'Position', [100 100 900 500]);

mean_data = zeros(num_scenarios, 2);
std_data = zeros(num_scenarios, 2);

for sc_idx = 1:num_scenarios
    sc_key = scenario_keys{sc_idx};
    mean_data(sc_idx, 1) = data.(sc_key).Baseline.delay_mean;
    mean_data(sc_idx, 2) = data.(sc_key).M2.delay_mean;
    std_data(sc_idx, 1) = data.(sc_key).Baseline.delay_mean_std;
    std_data(sc_idx, 2) = data.(sc_key).M2.delay_mean_std;
end

% NaN 처리
mean_data(isnan(mean_data)) = 0;
std_data(isnan(std_data)) = 0;

x = 1:num_scenarios;
width = 0.35;

b1 = bar(x - width/2, mean_data(:,1), width, 'FaceColor', colors.Baseline);
hold on;
b2 = bar(x + width/2, mean_data(:,2), width, 'FaceColor', colors.M2);

errorbar(x - width/2, mean_data(:,1), std_data(:,1), 'k', 'LineStyle', 'none', 'LineWidth', 1);
errorbar(x + width/2, mean_data(:,2), std_data(:,2), 'k', 'LineStyle', 'none', 'LineWidth', 1);

for i = 1:num_scenarios
    if mean_data(i,1) > 0
        text(i - width/2, mean_data(i,1) + std_data(i,1) + max(mean_data(:))*0.03, sprintf('%.0f', mean_data(i,1)), ...
            'HorizontalAlignment', 'center', 'FontSize', 9);
    end
    if mean_data(i,2) > 0
        text(i + width/2, mean_data(i,2) + std_data(i,2) + max(mean_data(:))*0.03, sprintf('%.0f', mean_data(i,2)), ...
            'HorizontalAlignment', 'center', 'FontSize', 9);
    end
end

hold off;
set(gca, 'XTick', x, 'XTickLabel', scenario_labels);
xlabel('Scenario');
ylabel('Mean Delay (ms)');
legend({'Baseline', 'M2'}, 'Location', 'northwest');
title('Figure 2: Mean Delay Comparison');
grid on;
saveas(gcf, fullfile(output_dir, 'fig02_mean_delay.png'));
fprintf('  ✓ Figure 2: Mean Delay 저장\n');

%% Figure 3: M2 개선율
figure('Name', 'Fig 3: M2 Improvement', 'Position', [100 100 700 500]);

improvements = zeros(num_scenarios, 1);
for sc_idx = 1:num_scenarios
    sc_key = scenario_keys{sc_idx};
    base_d = data.(sc_key).Baseline.delay_mean;
    m2_d = data.(sc_key).M2.delay_mean;
    if ~isnan(base_d) && ~isnan(m2_d) && base_d > 0
        improvements(sc_idx) = (base_d - m2_d) / base_d * 100;
    else
        improvements(sc_idx) = 0;
    end
end

b = bar(improvements);
b.FaceColor = 'flat';
b.CData = repmat(colors.M2, num_scenarios, 1);

for i = 1:num_scenarios
    text(i, improvements(i) + 2, sprintf('%.1f%%', improvements(i)), ...
        'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold');
end

set(gca, 'XTick', 1:num_scenarios, 'XTickLabel', scenario_labels);
xlabel('Scenario');
ylabel('Delay Improvement (%)');
title('Figure 3: M2 Delay Improvement (vs Baseline)');
ylim([min(0, min(improvements)*1.2), max(max(improvements)*1.2, 10)]);
grid on;
saveas(gcf, fullfile(output_dir, 'fig03_improvement.png'));
fprintf('  ✓ Figure 3: M2 개선율 저장\n');

%% Figure 4: UORA Collision Rate
figure('Name', 'Fig 4: UORA Collision', 'Position', [100 100 900 500]);

coll_rates = zeros(num_scenarios, 2);
for sc_idx = 1:num_scenarios
    sc_key = scenario_keys{sc_idx};
    for m_idx = 1:length(methods)
        method = methods{m_idx};
        d = data.(sc_key).(method);
        attempts = d.uora_success + d.uora_collision;
        if attempts > 0 && ~isnan(attempts)
            coll_rates(sc_idx, m_idx) = d.uora_collision / attempts * 100;
        end
    end
end

b = bar(coll_rates);
b(1).FaceColor = colors.Baseline;
b(2).FaceColor = colors.M2;

for i = 1:num_scenarios
    if coll_rates(i,1) > 0
        text(i - 0.15, coll_rates(i,1) + 2, sprintf('%.0f%%', coll_rates(i,1)), 'HorizontalAlignment', 'center', 'FontSize', 9);
    end
    if coll_rates(i,2) > 0
        text(i + 0.15, coll_rates(i,2) + 2, sprintf('%.0f%%', coll_rates(i,2)), 'HorizontalAlignment', 'center', 'FontSize', 9);
    end
end

set(gca, 'XTick', 1:num_scenarios, 'XTickLabel', scenario_labels);
xlabel('Scenario');
ylabel('UORA Collision Rate (%)');
legend({'Baseline', 'M2'}, 'Location', 'northwest');
title('Figure 4: UORA Collision Rate');
ylim([0 100]);
grid on;
saveas(gcf, fullfile(output_dir, 'fig04_uora_collision.png'));
fprintf('  ✓ Figure 4: UORA Collision Rate 저장\n');

%% Figure 5: M2 Hit Rate & Activations
figure('Name', 'Fig 5: M2 T_hold Stats', 'Position', [100 100 1000 500]);

subplot(1, 2, 1);
hit_rates = zeros(num_scenarios, 1);
for sc_idx = 1:num_scenarios
    sc_key = scenario_keys{sc_idx};
    hr = data.(sc_key).M2.hit_rate;
    if ~isnan(hr)
        hit_rates(sc_idx) = hr * 100;
    end
end

b = bar(hit_rates);
b.FaceColor = colors.M2;

for i = 1:num_scenarios
    text(i, hit_rates(i) + 2, sprintf('%.1f%%', hit_rates(i)), ...
        'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold');
end

set(gca, 'XTick', 1:num_scenarios, 'XTickLabel', scenario_labels);
xlabel('Scenario');
ylabel('T_{hold} Hit Rate (%)');
title('M2 T_{hold} Hit Rate');
ylim([0 100]);
grid on;

subplot(1, 2, 2);
activations = zeros(num_scenarios, 1);
for sc_idx = 1:num_scenarios
    sc_key = scenario_keys{sc_idx};
    act = data.(sc_key).M2.activations;
    if ~isnan(act)
        activations(sc_idx) = act;
    end
end

b = bar(activations);
b.FaceColor = colors.M2;

for i = 1:num_scenarios
    text(i, activations(i) + max(activations)*0.02, sprintf('%.0f', activations(i)), ...
        'HorizontalAlignment', 'center', 'FontSize', 10);
end

set(gca, 'XTick', 1:num_scenarios, 'XTickLabel', scenario_labels);
xlabel('Scenario');
ylabel('T_{hold} Activations');
title('M2 T_{hold} Activations');
grid on;

sgtitle('Figure 5: M2 T_{hold} Statistics', 'FontSize', 14, 'FontWeight', 'bold');
saveas(gcf, fullfile(output_dir, 'fig05_thold_stats.png'));
fprintf('  ✓ Figure 5: T_hold 통계 저장\n');

%% ═══════════════════════════════════════════════════════════════════════════
%  완료
%  ═══════════════════════════════════════════════════════════════════════════
fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗\n');
fprintf('║                                              분석 완료                                                            ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝\n\n');

fprintf('  ✓ 상세 통계 테이블 출력 완료\n');
fprintf('  ✓ 5개 Figure 저장: %s/\n', output_dir);