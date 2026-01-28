module CirclesOfChairs #(
    parameter N = 8,
    parameter DATA_WIDTH = 32,
    parameter RESULT_WIDTH = 64
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n,
    input wire [N*DATA_WIDTH-1:0] l_arr_packed,
    input wire [N*DATA_WIDTH-1:0] r_arr_packed,
    output reg [RESULT_WIDTH-1:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE     = 2'd0;
    localparam [1:0] SORT     = 2'd1;
    localparam [1:0] COMPUTE  = 2'd2;
    localparam [1:0] DONE_ST  = 2'd3;
    
    reg [1:0] state, next_state;
    
    // Memory arrays
    reg [DATA_WIDTH-1:0] l_mem [0:N-1];
    reg [DATA_WIDTH-1:0] r_mem [0:N-1];
    
    // Internal registers
    reg [7:0] n_reg;
    reg [RESULT_WIDTH-1:0] sum_reg;
    reg [7:0] i, j, k;
    
    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE:    next_state = start ? SORT : IDLE;
            SORT:    next_state = (i == N-2) ? COMPUTE : SORT;
            COMPUTE: next_state = (k == n_reg) ? DONE_ST : COMPUTE;
            DONE_ST: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end
    
    // Control logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= {RESULT_WIDTH{1'b0}};
            done <= 1'b0;
            sum_reg <= {RESULT_WIDTH{1'b0}};
            n_reg <= 8'd0;
            i <= 8'd0;
            j <= 8'd0;
            k <= 8'd0;
            for (integer idx = 0; idx < N; idx = idx + 1) begin
                l_mem[idx] <= {DATA_WIDTH{1'b0}};
                r_mem[idx] <= {DATA_WIDTH{1'b0}};
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        n_reg <= n;
                        sum_reg <= {RESULT_WIDTH{1'b0}};
                        // Unpack input arrays
                        for (integer idx = 0; idx < N; idx = idx + 1) begin
                            l_mem[idx] <= l_arr_packed[(idx*DATA_WIDTH) +: DATA_WIDTH];
                            r_mem[idx] <= r_arr_packed[(idx*DATA_WIDTH) +: DATA_WIDTH];
                        end
                        i <= 8'd0;
                        j <= 8'd0;
                        k <= 8'd0;
                    end
                end
                
                SORT: begin
                    if (i < N-1) begin
                        if (j < (N-1 - i)) begin
                            // Compare and swap l_mem
                            if (l_mem[j] > l_mem[j+1]) begin
                                l_mem[j]   <= l_mem[j+1];
                                l_mem[j+1] <= l_mem[j];
                            end
                            // Compare and swap r_mem
                            if (r_mem[j] > r_mem[j+1]) begin
                                r_mem[j]   <= r_mem[j+1];
                                r_mem[j+1] <= r_mem[j];
                            end
                            j <= j + 8'd1;
                        end else begin
                            j <= 8'd0;
                            i <= i + 8'd1;
                        end
                    end
                end
                
                COMPUTE: begin
                    if (k < n_reg) begin
                        if (l_mem[k] > r_mem[k]) begin
                            sum_reg <= sum_reg + l_mem[k];
                        end else begin
                            sum_reg <= sum_reg + r_mem[k];
                        end
                        k <= k + 8'd1;
                    end else begin
                        result <= n_reg + sum_reg;
                    end
                end
                
                DONE_ST: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule