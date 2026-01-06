%% analyze_exp1.m
% 추가 실험 1: 시스템 파라미터 변화 (RA-RU, STA) 분석
%
% 시나리오:
%   D-1: RA-RU=1, SA-RU=8, STA=20 (35% 부하)
%   D-2: RA-RU=2, SA-RU=7, STA=20 (40% 부하)
%   D-3: RA-RU=1, SA-RU=8, STA=50 (87% 부하)
%   D-4: RA-RU=2, SA-RU=7, STA=50 (99% 부하)
%
% 방법: Baseline, M2 (T_hold=50ms)

clear; clc;
fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗\n');
fprintf('║                          추가 실험 1: 시스템 파라미터 변화 분석                                                   ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝\n\n');

%% ═══════════════════════════════════════════════════════════════════════════
%  데이터 로드
%  ═══════════════════════════════════════════════════════════════════════════
fprintf('[데이터 로드]\n');

result_file = 'results/additional_exp1/results.mat';
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
% 실제 저장된 필드명: D_1, D_2, D_3, D_4 (하이픈이 언더스코어로 변환됨)
scenario_keys = {'D_1', 'D_2', 'D_3', 'D_4'};
scenario_labels = {'D-1', 'D-2', 'D-3', 'D-4'};
scenario_desc = {
    'RA=1, SA=8, STA=20 (35%)', 
    'RA=2, SA=7, STA=20 (40%)', 
    'RA=1, SA=8, STA=50 (87%)', 
    'RA=2, SA=7, STA=50 (99%)'
};
methods = {'Baseline', 'M2'};
num_seeds = 3;
num_scenarios = 4;

% 색상
colors.Baseline = [0.5 0.5 0.5];           % 회색
colors.M2 = [0.466 0.674 0.188];           % 녹색

output_dir = 'results/figures_exp1';
if ~exist(output_dir, 'dir'), mkdir(output_dir); end

%% ═══════════════════════════════════════════════════════════════════════════
%  PART 1: 시나리오 파라미터 요약
%  ═══════════════════════════════════════════════════════════════════════════
fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗\n');
fprintf('║                                         시나리오 파라미터                                                        ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝\n\n');

fprintf('┌──────────┬────────┬────────┬───────┬────────────┬──────────┐\n');
fprintf('│ 시나리오  │ RA-RU  │ SA-RU  │  STA  │ 전체 부하   │ 용량 대비 │\n');
fprintf('├──────────┼────────┼────────┼───────┼────────────┼──────────┤\n');
fprintf('│   D-1    │   1    │   8    │  20   │ 1000 pkt/s │   35%%    │\n');
fprintf('│   D-2    │   2    │   7    │  20   │ 1000 pkt/s │   40%%    │\n');
fprintf('│   D-3    │   1    │   8    │  50   │ 2500 pkt/s │   87%%    │\n');
fprintf('│   D-4    │   2    │   7    │  50   │ 2500 pkt/s │   99%%    │\n');
fprintf('└──────────┴────────┴────────┴───────┴────────────┴──────────┘\n\n');

fprintf('■ 비교 포인트:\n');
fprintf('  - RA-RU 증가 효과: D-1 vs D-2, D-3 vs D-4\n');
fprintf('  - STA 증가 효과: D-1 vs D-3, D-2 vs D-4\n');
fprintf('  - M2 효과: 각 시나리오에서 Baseline vs M2\n\n');

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
        
        % 평균 저장
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
        if ~isempty(pkt_generated) && ~isempty(pkt_completed)
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
            fprintf('│   %s    │ %-8s │ %7.1f±%.1f│ %10.1f │ %10.1f │ %10.1f │ %10.1f │ %10.0f │     -      │\n', ...
                sc_label, method, d.delay_mean, d.delay_mean_std, d.delay_std, d.p10, d.p50, d.p90, d.count);
        else
            improvement = (base_mean - d.delay_mean) / base_mean * 100;
            fprintf('│   %s    │ %-8s │ %7.1f±%.1f│ %10.1f │ %10.1f │ %10.1f │ %10.1f │ %10.0f │ %+6.1f%%    │\n', ...
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
    
    fprintf('│   %s    │ %10.0f │ %10.0f │ %10.0f │ %8.1f%%  │\n', ...
        sc_label, d.activations, d.hits, d.phantoms, d.hit_rate*100);
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
        if attempts > 0
            coll_rate = d.uora_collision / attempts * 100;
        else
            coll_rate = 0;
        end
        
        fprintf('│   %s    │ %-8s │ %10.0f │ %10.0f │ %10.0f │ %8.1f%%  │\n', ...
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
        
        fprintf('│   %s    │ %-8s │ %10.2f │ %10.0f │ %10.0f │ %8.1f%%  │\n', ...
            sc_label, method, d.throughput, d.pkt_generated, d.pkt_completed, d.completion_rate);
    end
    
    if sc_idx < num_scenarios
        fprintf('├──────────┼──────────┼────────────┼────────────┼────────────┼────────────┤\n');
    end
end
fprintf('└──────────┴──────────┴────────────┴────────────┴────────────┴────────────┘\n\n');

%% ═══════════════════════════════════════════════════════════════════════════
%  PART 6: 비교 분석
%  ═══════════════════════════════════════════════════════════════════════════
fprintf('╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗\n');
fprintf('║                                         비교 분석                                                                ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝\n\n');

% RA-RU 증가 효과 (1 → 2)
fprintf('■ RA-RU 증가 효과 (1 → 2)\n');
fprintf('┌────────────────┬─────────────────────────────────────────────────────────┐\n');
fprintf('│ 비교           │ Mean Delay 변화                                          │\n');
fprintf('├────────────────┼─────────────────────────────────────────────────────────┤\n');

% D-1 vs D-2 (Baseline)
d1b = data.D_1.Baseline.delay_mean;
d2b = data.D_2.Baseline.delay_mean;
change = (d2b - d1b) / d1b * 100;
fprintf('│ D-1 → D-2 Base │ %.1fms → %.1fms (%+.1f%%)                              \n', d1b, d2b, change);

% D-1 vs D-2 (M2)
d1m = data.D_1.M2.delay_mean;
d2m = data.D_2.M2.delay_mean;
change = (d2m - d1m) / d1m * 100;
fprintf('│ D-1 → D-2 M2   │ %.1fms → %.1fms (%+.1f%%)                              \n', d1m, d2m, change);

% D-3 vs D-4 (Baseline)
d3b = data.D_3.Baseline.delay_mean;
d4b = data.D_4.Baseline.delay_mean;
change = (d4b - d3b) / d3b * 100;
fprintf('│ D-3 → D-4 Base │ %.1fms → %.1fms (%+.1f%%)                              \n', d3b, d4b, change);

% D-3 vs D-4 (M2)
d3m = data.D_3.M2.delay_mean;
d4m = data.D_4.M2.delay_mean;
change = (d4m - d3m) / d3m * 100;
fprintf('│ D-3 → D-4 M2   │ %.1fms → %.1fms (%+.1f%%)                              \n', d3m, d4m, change);
fprintf('└────────────────┴─────────────────────────────────────────────────────────┘\n\n');

% STA 증가 효과 (20 → 50)
fprintf('■ STA 증가 효과 (20 → 50)\n');
fprintf('┌────────────────┬─────────────────────────────────────────────────────────┐\n');
fprintf('│ 비교           │ Mean Delay 변화                                          │\n');
fprintf('├────────────────┼─────────────────────────────────────────────────────────┤\n');

change = (d3b - d1b) / d1b * 100;
fprintf('│ D-1 → D-3 Base │ %.1fms → %.1fms (%+.1f%%)                             \n', d1b, d3b, change);

change = (d3m - d1m) / d1m * 100;
fprintf('│ D-1 → D-3 M2   │ %.1fms → %.1fms (%+.1f%%)                             \n', d1m, d3m, change);

change = (d4b - d2b) / d2b * 100;
fprintf('│ D-2 → D-4 Base │ %.1fms → %.1fms (%+.1f%%)                             \n', d2b, d4b, change);

change = (d4m - d2m) / d2m * 100;
fprintf('│ D-2 → D-4 M2   │ %.1fms → %.1fms (%+.1f%%)                             \n', d2m, d4m, change);
fprintf('└────────────────┴─────────────────────────────────────────────────────────┘\n\n');

%% ═══════════════════════════════════════════════════════════════════════════
%  Figure 생성
%  ═══════════════════════════════════════════════════════════════════════════
fprintf('╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗\n');
fprintf('║                                           Figure 생성                                                            ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝\n\n');

%% Figure 1: Delay CDF (2x2 grid)
figure('Name', 'Fig 1: Delay CDF', 'Position', [100 100 1200 900]);

for sc_idx = 1:num_scenarios
    sc_key = scenario_keys{sc_idx};
    sc_label = scenario_labels{sc_idx};
    subplot(2, 2, sc_idx);
    
    hold on;
    
    % Baseline
    delays_base = [];
    for s = 1:num_seeds
        field_name = sprintf('%s_Baseline_s%d', sc_key, s);
        if isfield(results.runs, field_name)
            r = results.runs.(field_name);
            if isfield(r, 'delay')
                % all_ms, all_delays_ms 또는 all_delays 시도
                if isfield(r.delay, 'all_ms')
                    delays_base = [delays_base; r.delay.all_ms(:)];
                elseif isfield(r.delay, 'all_delays_ms')
                    delays_base = [delays_base; r.delay.all_delays_ms(:)];
                elseif isfield(r.delay, 'all_delays')
                    delays_base = [delays_base; r.delay.all_delays(:) * 1000]; % s -> ms
                end
            end
        end
    end
    
    if ~isempty(delays_base)
        % 수동 CDF 계산 (ecdf 대체)
        x_base = sort(delays_base);
        f_base = (1:length(x_base))' / length(x_base);
        plot(x_base, f_base, '-', 'Color', colors.Baseline, 'LineWidth', 2, 'DisplayName', 'Baseline');
    else
        fprintf('  ⚠ %s Baseline: all_delays 데이터 없음\n', sc_label);
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
                elseif isfield(r.delay, 'all_delays')
                    delays_m2 = [delays_m2; r.delay.all_delays(:) * 1000];
                end
            end
        end
    end
    
    if ~isempty(delays_m2)
        % 수동 CDF 계산 (ecdf 대체)
        x_m2 = sort(delays_m2);
        f_m2 = (1:length(x_m2))' / length(x_m2);
        plot(x_m2, f_m2, '-', 'Color', colors.M2, 'LineWidth', 2, 'DisplayName', 'M2');
    else
        fprintf('  ⚠ %s M2: all_delays 데이터 없음\n', sc_label);
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
        xlim([0 min(1500, prctile(all_delays, 99)*1.2)]);
    end
end

% CDF 데이터 없으면 경고
first_run = fieldnames(results.runs);
if ~isempty(first_run)
    r = results.runs.(first_run{1});
    if isfield(r, 'delay')
        delay_fields = fieldnames(r.delay);
        if ~any(strcmp(delay_fields, 'all_ms')) && ~any(strcmp(delay_fields, 'all_delays_ms')) && ~any(strcmp(delay_fields, 'all_delays'))
            fprintf('\n  ⚠ CDF를 그리려면 all_ms, all_delays_ms 또는 all_delays 필드가 필요합니다.\n');
            fprintf('    현재 delay 필드: %s\n', strjoin(delay_fields, ', '));
        end
    end
end

sgtitle('Figure 1: Delay CDF', 'FontSize', 14, 'FontWeight', 'bold');
saveas(gcf, fullfile(output_dir, 'fig01_delay_cdf.png'));
fprintf('  ✓ Figure 1: Delay CDF 저장\n');

%% Figure 2: Mean Delay 비교
figure('Name', 'Fig 2: Mean Delay', 'Position', [100 100 1000 500]);

mean_data = zeros(num_scenarios, 2);
std_data = zeros(num_scenarios, 2);

for sc_idx = 1:num_scenarios
    sc_key = scenario_keys{sc_idx};
    mean_data(sc_idx, 1) = data.(sc_key).Baseline.delay_mean;
    mean_data(sc_idx, 2) = data.(sc_key).M2.delay_mean;
    std_data(sc_idx, 1) = data.(sc_key).Baseline.delay_mean_std;
    std_data(sc_idx, 2) = data.(sc_key).M2.delay_mean_std;
end

x = 1:num_scenarios;
width = 0.35;

b1 = bar(x - width/2, mean_data(:,1), width, 'FaceColor', colors.Baseline);
hold on;
b2 = bar(x + width/2, mean_data(:,2), width, 'FaceColor', colors.M2);

errorbar(x - width/2, mean_data(:,1), std_data(:,1), 'k', 'LineStyle', 'none', 'LineWidth', 1);
errorbar(x + width/2, mean_data(:,2), std_data(:,2), 'k', 'LineStyle', 'none', 'LineWidth', 1);

for i = 1:num_scenarios
    text(i - width/2, mean_data(i,1) + std_data(i,1) + max(mean_data(:))*0.03, sprintf('%.0f', mean_data(i,1)), ...
        'HorizontalAlignment', 'center', 'FontSize', 9);
    text(i + width/2, mean_data(i,2) + std_data(i,2) + max(mean_data(:))*0.03, sprintf('%.0f', mean_data(i,2)), ...
        'HorizontalAlignment', 'center', 'FontSize', 9);
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
figure('Name', 'Fig 3: M2 Improvement', 'Position', [100 100 800 500]);

improvements = zeros(num_scenarios, 1);
for sc_idx = 1:num_scenarios
    sc_key = scenario_keys{sc_idx};
    base_d = data.(sc_key).Baseline.delay_mean;
    m2_d = data.(sc_key).M2.delay_mean;
    improvements(sc_idx) = (base_d - m2_d) / base_d * 100;
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
ylim([0 max(max(improvements)*1.2, 10)]);
grid on;
saveas(gcf, fullfile(output_dir, 'fig03_improvement.png'));
fprintf('  ✓ Figure 3: M2 개선율 저장\n');

%% Figure 4: UORA Collision Rate
figure('Name', 'Fig 4: UORA Collision', 'Position', [100 100 1000 500]);

coll_rates = zeros(num_scenarios, 2);
for sc_idx = 1:num_scenarios
    sc_key = scenario_keys{sc_idx};
    for m_idx = 1:length(methods)
        method = methods{m_idx};
        d = data.(sc_key).(method);
        attempts = d.uora_success + d.uora_collision;
        if attempts > 0
            coll_rates(sc_idx, m_idx) = d.uora_collision / attempts * 100;
        end
    end
end

b = bar(coll_rates);
b(1).FaceColor = colors.Baseline;
b(2).FaceColor = colors.M2;

for i = 1:num_scenarios
    text(i - 0.15, coll_rates(i,1) + 2, sprintf('%.0f%%', coll_rates(i,1)), 'HorizontalAlignment', 'center', 'FontSize', 9);
    text(i + 0.15, coll_rates(i,2) + 2, sprintf('%.0f%%', coll_rates(i,2)), 'HorizontalAlignment', 'center', 'FontSize', 9);
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

%% Figure 5: RA-RU 효과 분석
figure('Name', 'Fig 5: RA-RU Effect', 'Position', [100 100 1000 500]);

subplot(1, 2, 1);
data_low = [data.D_1.Baseline.delay_mean, data.D_1.M2.delay_mean;
            data.D_2.Baseline.delay_mean, data.D_2.M2.delay_mean];
b = bar(data_low);
b(1).FaceColor = colors.Baseline;
b(2).FaceColor = colors.M2;
set(gca, 'XTick', 1:2, 'XTickLabel', {'RA=1 (D-1)', 'RA=2 (D-2)'});
xlabel('RA-RU Configuration');
ylabel('Mean Delay (ms)');
title('Low Load (STA=20)');
legend({'Baseline', 'M2'}, 'Location', 'northwest');
grid on;

subplot(1, 2, 2);
data_high = [data.D_3.Baseline.delay_mean, data.D_3.M2.delay_mean;
             data.D_4.Baseline.delay_mean, data.D_4.M2.delay_mean];
b = bar(data_high);
b(1).FaceColor = colors.Baseline;
b(2).FaceColor = colors.M2;
set(gca, 'XTick', 1:2, 'XTickLabel', {'RA=1 (D-3)', 'RA=2 (D-4)'});
xlabel('RA-RU Configuration');
ylabel('Mean Delay (ms)');
title('High Load (STA=50)');
legend({'Baseline', 'M2'}, 'Location', 'northwest');
grid on;

sgtitle('Figure 5: RA-RU Increase Effect', 'FontSize', 14, 'FontWeight', 'bold');
saveas(gcf, fullfile(output_dir, 'fig05_ra_effect.png'));
fprintf('  ✓ Figure 5: RA-RU 효과 저장\n');

%% Figure 6: STA 효과 분석
figure('Name', 'Fig 6: STA Effect', 'Position', [100 100 1000 500]);

subplot(1, 2, 1);
data_ra1 = [data.D_1.Baseline.delay_mean, data.D_1.M2.delay_mean;
            data.D_3.Baseline.delay_mean, data.D_3.M2.delay_mean];
b = bar(data_ra1);
b(1).FaceColor = colors.Baseline;
b(2).FaceColor = colors.M2;
set(gca, 'XTick', 1:2, 'XTickLabel', {'STA=20 (D-1)', 'STA=50 (D-3)'});
xlabel('Number of STAs');
ylabel('Mean Delay (ms)');
title('RA-RU = 1');
legend({'Baseline', 'M2'}, 'Location', 'northwest');
grid on;

subplot(1, 2, 2);
data_ra2 = [data.D_2.Baseline.delay_mean, data.D_2.M2.delay_mean;
            data.D_4.Baseline.delay_mean, data.D_4.M2.delay_mean];
b = bar(data_ra2);
b(1).FaceColor = colors.Baseline;
b(2).FaceColor = colors.M2;
set(gca, 'XTick', 1:2, 'XTickLabel', {'STA=20 (D-2)', 'STA=50 (D-4)'});
xlabel('Number of STAs');
ylabel('Mean Delay (ms)');
title('RA-RU = 2');
legend({'Baseline', 'M2'}, 'Location', 'northwest');
grid on;

sgtitle('Figure 6: STA Increase Effect', 'FontSize', 14, 'FontWeight', 'bold');
saveas(gcf, fullfile(output_dir, 'fig06_sta_effect.png'));
fprintf('  ✓ Figure 6: STA 효과 저장\n');

%% Figure 7: M2 Hit Rate
figure('Name', 'Fig 7: Hit Rate', 'Position', [100 100 800 500]);

hit_rates = zeros(num_scenarios, 1);
for sc_idx = 1:num_scenarios
    sc_key = scenario_keys{sc_idx};
    hit_rates(sc_idx) = data.(sc_key).M2.hit_rate * 100;
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
title('Figure 7: M2 T_{hold} Hit Rate');
ylim([0 100]);
grid on;
saveas(gcf, fullfile(output_dir, 'fig07_hit_rate.png'));
fprintf('  ✓ Figure 7: Hit Rate 저장\n');

%% ═══════════════════════════════════════════════════════════════════════════
%  완료
%  ═══════════════════════════════════════════════════════════════════════════
fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗\n');
fprintf('║                                              분석 완료                                                            ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝\n\n');

fprintf('  ✓ 상세 통계 테이블 출력 완료\n');
fprintf('  ✓ 7개 Figure 저장: %s/\n', output_dir);