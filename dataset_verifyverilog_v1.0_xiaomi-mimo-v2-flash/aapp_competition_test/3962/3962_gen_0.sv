module dinner_seating_problem(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] l_in,
    input wire [31:0] r_in,
    input wire load_en,
    output reg [31:0] result,
    output reg done,
    output reg ready
);

    // Constants
    localparam [7:0] N = 8'd16;
    localparam [31:0] MAX_CYCLES = 32'd5000;
    localparam [4:0] MAX_IDX = 5'd15;
    
    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOADING = 3'd1;
    localparam [2:0] SORT_L = 3'd2;
    localparam [2:0] SORT_R = 3'd3;
    localparam [2:0] COMPUTE_SUM = 3'd4;
    localparam [2:0] FINISH = 3'd5;
    
    // Internal registers
    reg [2:0] state, next_state;
    reg [4:0] load_idx;
    reg [31:0] l_array [0:15];
    reg [31:0] r_array [0:15];
    reg [4:0] sort_i;
    reg [4:0] sort_j;
    reg [31:0] temp_l;
    reg [31:0] temp_r;
    reg [4:0] compute_idx;
    reg [31:0] sum_temp;
    reg [31:0] cycle_count;
    
    // Helper variables for loops
    integer i;
    
    // Combinational logic for ready signal
    always @(*) begin
        ready = (state == LOADING && load_idx < N);
    end
    
    // State transition and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            load_idx <= 5'd0;
            sort_i <= 5'd0;
            sort_j <= 5'd0;
            compute_idx <= 5'd0;
            sum_temp <= 32'd0;
            cycle_count <= 32'd0;
            for (i = 0; i < 16; i = i + 1) begin
                l_array[i] <= 32'd0;
                r_array[i] <= 32'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 32'd0;
                    load_idx <= 5'd0;
                    sort_i <= 5'd0;
                    sort_j <= 5'd0;
                    compute_idx <= 5'd0;
                    sum_temp <= 32'd0;
                    cycle_count <= 32'd0;
                    if (start) begin
                        state <= LOADING;
                    end
                end
                
                LOADING: begin
                    if (load_en && load_idx < N) begin
                        l_array[load_idx] <= l_in;
                        r_array[load_idx] <= r_in;
                        load_idx <= load_idx + 5'd1;
                    end
                    if (load_idx == N && !load_en) begin
                        state <= SORT_L;
                    end
                end
                
                SORT_L: begin
                    cycle_count <= cycle_count + 32'd1;
                    // Bubble sort pass for l_array
                    if (sort_i < N - 1) begin
                        if (sort_j < N - sort_i - 1) begin
                            if (l_array[sort_j] > l_array[sort_j + 1]) begin
                                temp_l <= l_array[sort_j];
                                l_array[sort_j] <= l_array[sort_j + 1];
                                l_array[sort_j + 1] <= temp_l;
                            end
                            sort_j <= sort_j + 5'd1;
                        end else begin
                            sort_j <= 5'd0;
                            sort_i <= sort_i + 5'd1;
                        end
                    end else begin
                        sort_i <= 5'd0;
                        sort_j <= 5'd0;
                        state <= SORT_R;
                    end
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                SORT_R: begin
                    cycle_count <= cycle_count + 32'd1;
                    // Bubble sort pass for r_array
                    if (sort_i < N - 1) begin
                        if (sort_j < N - sort_i - 1) begin
                            if (r_array[sort_j] > r_array[sort_j + 1]) begin
                                temp_r <= r_array[sort_j];
                                r_array[sort_j] <= r_array[sort_j + 1];
                                r_array[sort_j + 1] <= temp_r;
                            end
                            sort_j <= sort_j + 5'd1;
                        end else begin
                            sort_j <= 5'd0;
                            sort_i <= sort_i + 5'd1;
                        end
                    end else begin
                        sort_i <= 5'd0;
                        sort_j <= 5'd0;
                        state <= COMPUTE_SUM;
                    end
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                COMPUTE_SUM: begin
                    cycle_count <= cycle_count + 32'd1;
                    if (compute_idx < N) begin
                        // Compute max(l[i], r[i]) + 1
                        if (l_array[compute_idx] > r_array[compute_idx]) begin
                            sum_temp <= sum_temp + l_array[compute_idx] + 32'd1;
                        end else begin
                            sum_temp <= sum_temp + r_array[compute_idx] + 32'd1;
                        end
                        compute_idx <= compute_idx + 5'd1;
                    end else begin
                        result <= sum_temp;
                        state <= FINISH;
                    end
                    if (cycle_count >= MAX_CYCLES) begin
                        result <= sum_temp;
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    result <= 32'd0;
                end
            endcase
        end
    end

endmodule