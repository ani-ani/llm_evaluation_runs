module xray_optimal_energies (
    input clk,
    input rst_n,
    input start,
    input [5:0] n,
    input [3:0] m,
    input [31:0] k_data,
    input [5:0] bin_index,
    input k_wr,
    output reg [31:0] min_sum,
    output reg done,
    output reg valid
);

    // Parameters
    localparam IDLE = 4'b0001;
    localparam LOAD_K = 4'b0010;
    localparam INIT_E = 4'b0100;
    localparam ITERATE = 4'b1000;
    localparam ASSIGN = 4'b0011;
    localparam UPDATE = 4'b0101;
    localparam CALC_SUM = 4'b0110;
    localparam DONE = 4'b1000;

    // Internal registers
    reg [3:0] state;
    reg [5:0] bin_counter;
    reg [2:0] iter_counter;
    reg [3:0] cluster_counter;
    reg [31:0] k_ram [0:63];
    reg [31:0] E [0:7];
    reg [31:0] E_prev [0:7];
    reg [31:0] cluster_sum [0:7];
    reg [31:0] weight_sum [0:7];
    reg [31:0] distance [0:63];
    reg [2:0] assignment [0:63];
    reg [31:0] sum_squared;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            bin_counter <= 0;
            iter_counter <= 0;
            cluster_counter <= 0;
            min_sum <= 0;
            done <= 0;
            valid <= 0;
            sum_squared <= 0;
            for (int i = 0; i < 64; i = i + 1) begin
                k_ram[i] <= 0;
                assignment[i] <= 0;
            end
            for (int j = 0; j < 8; j = j + 1) begin
                E[j] <= 0;
                E_prev[j] <= 0;
                cluster_sum[j] <= 0;
                weight_sum[j] <= 0;
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= LOAD_K;
                        bin_counter <= 0;
                    end
                end
                LOAD_K: begin
                    if (k_wr) begin
                        k_ram[bin_index] <= k_data;
                        bin_counter <= bin_counter + 1;
                        if (bin_counter == n) begin
                            state <= INIT_E;
                        end
                    end
                end
                INIT_E: begin
                    for (int j = 0; j < m; j = j + 1) begin
                        E[j] <= (j + 1) * (n << 16) / (m + 1);
                    end
                    state <= ITERATE;
                    iter_counter <= 0;
                end
                ITERATE: begin
                    if (iter_counter < 6) begin
                        state <= ASSIGN;
                        bin_counter <= 0;
                    end else begin
                        state <= CALC_SUM;
                    end
                end
                ASSIGN: begin
                    if (bin_counter < n) begin
                        // Compute distances and assignments
                        for (int j = 0; j < m; j = j + 1) begin
                            distance[bin_counter] = (bin_counter + 1 - (E[j] >> 16)) * (bin_counter + 1 - (E[j] >> 16));
                        end
                        // Find closest cluster
                        assignment[bin_counter] = 0;
                        for (int j = 1; j < m; j = j + 1) begin
                            if (distance[bin_counter] > (bin_counter + 1 - (E[j] >> 16)) * (bin_counter + 1 - (E[j] >> 16))) begin
                                distance[bin_counter] = (bin_counter + 1 - (E[j] >> 16)) * (bin_counter + 1 - (E[j] >> 16));
                                assignment[bin_counter] = j;
                            end
                        end
                        bin_counter <= bin_counter + 1;
                        if (bin_counter == n) begin
                            state <= UPDATE;
                            cluster_counter <= 0;
                        end
                    end
                end
                UPDATE: begin
                    if (cluster_counter < m) begin
                        cluster_sum[cluster_counter] <= 0;
                        weight_sum[cluster_counter] <= 0;
                        for (int i = 0; i < n; i = i + 1) begin
                            if (assignment[i] == cluster_counter) begin
                                cluster_sum[cluster_counter] <= cluster_sum[cluster_counter] + (i + 1) * k_ram[i];
                                weight_sum[cluster_counter] <= weight_sum[cluster_counter] + k_ram[i];
                            end
                        end
                        if (weight_sum[cluster_counter] != 0) begin
                            E_prev[cluster_counter] <= E[cluster_counter];
                            E[cluster_counter] <= (cluster_sum[cluster_counter] << 16) / weight_sum[cluster_counter];
                        end
                        cluster_counter <= cluster_counter + 1;
                        if (cluster_counter == m) begin
                            state <= ITERATE;
                            iter_counter <= iter_counter + 1;
                        end
                    end
                end
                CALC_SUM: begin
                    sum_squared <= 0;
                    for (int i = 0; i < n; i = i + 1) begin
                        sum_squared <= sum_squared + k_ram[i] * (i + 1 - (E[assignment[i]] >> 16)) * (i + 1 - (E[assignment[i]] >> 16));
                    end
                    min_sum <= sum_squared;
                    state <= DONE;
                end
                DONE: begin
                    done <= 1;
                    valid <= 1;
                    if (start) begin
                        state <= IDLE;
                        done <= 0;
                        valid <= 0;
                    end
                end
            endcase
        end
    end

endmodule