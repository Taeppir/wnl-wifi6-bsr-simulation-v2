function summary = summarize_results(results, cfg)
% SUMMARIZE_RESULTS: 시뮬레이션 결과를 CSV용 구조체로 요약
%
% 입력:
%   results - Simulator.run() 결과
%   cfg - 설정 구조체
% 출력:
%   summary - 요약 구조체

    summary = struct();
    
    %% ═══════════════════════════════════════════════════
    %  실험 설정
    %  ═══════════════════════════════════════════════════
    
    summary.exp_id = results.exp_id;
    summary.phase = results.phase;
    summary.num_stas = cfg.num_stas;
    summary.num_ru_ra = cfg.num_ru_ra;
    summary.num_ru_sa = cfg.num_ru_sa;
    summary.rho = cfg.rho;
    summary.lambda = cfg.lambda;
    summary.thold_ms = cfg.thold_value * 1000;
    summary.mu_on_ms = cfg.mu_on * 1000;
    summary.mu_off_ms = cfg.mu_off * 1000;
    
    % T_hold Coverage 계산
    if cfg.mu_off > 0
        summary.thold_coverage = (cfg.thold_value / cfg.mu_off) * 100;
    else
        summary.thold_coverage = 0;
    end
    
    %% ═══════════════════════════════════════════════════
    %  지연 지표
    %  ═══════════════════════════════════════════════════
    
    summary.delay_mean_ms = results.delay.mean_ms;
    summary.delay_std_ms = results.delay.std_ms;
    summary.delay_p50_ms = results.delay.p50_ms;
    summary.delay_p90_ms = results.delay.p90_ms;
    summary.delay_p99_ms = results.delay.p99_ms;
    summary.delay_max_ms = results.delay.max_ms;
    
    %% ═══════════════════════════════════════════════════
    %  지연 분해 (delay_decomp)
    %  ═══════════════════════════════════════════════════
    
    if isfield(results, 'delay_decomp')
        dd = results.delay_decomp;
        summary.initial_wait_ms = dd.initial_wait.mean_ms;
        summary.uora_contention_ms = dd.uora_contention.mean_ms;
        summary.uora_contention_when_used_ms = dd.uora_contention.mean_when_used_ms;
        summary.sa_wait_ms = dd.sa_wait.mean_ms;
        
        if isfield(dd, 'thold_hit') && dd.thold_hit.count > 0
            summary.thold_hit_delay_ms = dd.thold_hit.mean_ms;
            summary.thold_hit_count = dd.thold_hit.count;
        else
            summary.thold_hit_delay_ms = NaN;
            summary.thold_hit_count = 0;
        end
        
        if isfield(dd, 'non_thold') && dd.non_thold.count > 0
            summary.non_thold_delay_ms = dd.non_thold.mean_ms;
            summary.non_thold_count = dd.non_thold.count;
        else
            summary.non_thold_delay_ms = NaN;
            summary.non_thold_count = 0;
        end
        
        % RA vs SA 패킷 수
        if isfield(dd, 'ra_packets')
            summary.ra_packets = dd.ra_packets.count;
            summary.ra_packets_delay_ms = dd.ra_packets.mean_ms;
        else
            summary.ra_packets = 0;
            summary.ra_packets_delay_ms = NaN;
        end
        if isfield(dd, 'sa_packets')
            summary.sa_packets = dd.sa_packets.count;
            summary.sa_packets_delay_ms = dd.sa_packets.mean_ms;
        else
            summary.sa_packets = 0;
            summary.sa_packets_delay_ms = NaN;
        end
    else
        summary.initial_wait_ms = NaN;
        summary.uora_contention_ms = NaN;
        summary.uora_contention_when_used_ms = NaN;
        summary.sa_wait_ms = NaN;
        summary.thold_hit_delay_ms = NaN;
        summary.thold_hit_count = 0;
        summary.non_thold_delay_ms = NaN;
        summary.non_thold_count = 0;
        summary.ra_packets = 0;
        summary.ra_packets_delay_ms = NaN;
        summary.sa_packets = 0;
        summary.sa_packets_delay_ms = NaN;
    end
    
    %% ═══════════════════════════════════════════════════
    %  T_hold 지표
    %  ═══════════════════════════════════════════════════
    
    if isfield(results, 'thold')
        summary.thold_activations = results.thold.activations;
        summary.thold_hits = results.thold.hits;
        summary.thold_expirations = results.thold.expirations;
        
        % 세분화된 expiration 통계
        if isfield(results.thold, 'expirations_empty')
            summary.thold_expirations_empty = results.thold.expirations_empty;
        else
            summary.thold_expirations_empty = results.thold.expirations;
        end
        if isfield(results.thold, 'expirations_with_data')
            summary.thold_expirations_with_data = results.thold.expirations_with_data;
        else
            summary.thold_expirations_with_data = 0;
        end
        
        summary.thold_hit_rate = results.thold.hit_rate;
        summary.thold_wasted_slots = results.thold.wasted_slots;
        summary.thold_wasted_ms = results.thold.wasted_slots * 0.009;
        
        if isfield(results.thold, 'phantom_count')
            summary.thold_phantom_count = results.thold.phantom_count;
        else
            summary.thold_phantom_count = 0;
        end
    else
        summary.thold_activations = 0;
        summary.thold_hits = 0;
        summary.thold_expirations = 0;
        summary.thold_expirations_empty = 0;
        summary.thold_expirations_with_data = 0;
        summary.thold_hit_rate = 0;
        summary.thold_wasted_slots = 0;
        summary.thold_wasted_ms = 0;
        summary.thold_phantom_count = 0;
    end
    
    %% ═══════════════════════════════════════════════════
    %  UORA/충돌 지표
    %  ═══════════════════════════════════════════════════
    
    summary.uora_success = results.uora.total_success;
    summary.uora_collision = results.uora.total_collision;
    summary.uora_collision_slots = results.uora.total_collision_slots;
    summary.uora_idle = results.uora.total_idle;
    summary.uora_success_rate = results.uora.success_rate;
    summary.uora_collision_rate = results.uora.collision_rate;
    summary.uora_collision_slot_rate = results.uora.collision_slot_rate;
    summary.uora_idle_rate = results.uora.idle_rate;
    summary.uora_avg_collision_size = results.uora.avg_collision_size;
    summary.uora_collisions_per_pkt = results.uora.collisions_per_packet;
    
    %% ═══════════════════════════════════════════════════
    %  처리율/효율
    %  ═══════════════════════════════════════════════════
    
    summary.throughput_mbps = results.throughput.total_mbps;
    summary.ra_utilization = results.throughput.ra_utilization;
    summary.sa_utilization = results.throughput.sa_utilization;
    summary.sa_phantom_rate = results.throughput.sa_phantom_rate;
    summary.channel_utilization = results.throughput.channel_utilization;
    
    %% ═══════════════════════════════════════════════════
    %  패킷
    %  ═══════════════════════════════════════════════════
    
    summary.packets_generated = results.packets.generated;
    summary.packets_completed = results.packets.completed;
    summary.completion_rate = results.packets.completion_rate;
    
    %% ═══════════════════════════════════════════════════
    %  공정성
    %  ═══════════════════════════════════════════════════
    
    summary.jain_index = results.fairness.jain_index;
    summary.cov = results.fairness.cov;
    if isfield(results.fairness, 'min_max_ratio')
        summary.min_max_ratio = results.fairness.min_max_ratio;
    else
        summary.min_max_ratio = 1;
    end
    
    %% ═══════════════════════════════════════════════════
    %  BSR
    %  ═══════════════════════════════════════════════════
    
    summary.bsr_explicit = results.bsr.explicit_count;
    summary.bsr_implicit = results.bsr.implicit_count;
    summary.bsr_explicit_ratio = results.bsr.explicit_ratio;
    
    %% ═══════════════════════════════════════════════════
    %  TF
    %  ═══════════════════════════════════════════════════
    
    summary.tf_count = results.tf.count;
    summary.tf_period_ms = results.tf.period_ms;
end