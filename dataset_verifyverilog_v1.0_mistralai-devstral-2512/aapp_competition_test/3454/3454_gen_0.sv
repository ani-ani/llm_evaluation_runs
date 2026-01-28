module PokenomPainting(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [9:0] N,
    input wire [9:0] M,
    input wire [9:0] c_in,
    output reg [16:0] result,
    output reg [9:0] X,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD_C = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINISH = 3'd3;
    
    reg [2:0] state, next_state;
    reg [9:0] col_idx;
    reg [9:0] height_idx;
    reg [9:0] H_limit;
    reg [9:0] H_max;
    reg [9:0] c_mem [0:999];
    reg [16:0] dp_prev [0:1023];
    reg [16:0] dp_curr [0:1023];
    reg [9:0] zero_count;
    reg [16:0] temp_sum;
    reg [9:0] i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            col_idx <= 10'd0;
            height_idx <= 10'd0;
            H_limit <= 10'd0;
            H_max <= 10'd0;
            zero_count <= 10'd0;
            result <= 17'd0;
            X <= 10'd0;
            done <= 1'b0;
            
            // Initialize c_mem
            for (i = 0; i < 1000; i = i + 1) begin
                c_mem[i] <= 10'd0;
            end
            
            // Initialize dp_prev and dp_curr
            for (i = 0; i < 1024; i = i + 1) begin
                dp_prev[i] <= 17'd0;
                dp_curr[i] <= 17'd0;
            end
        end else begin
            state <= next_state;
        end
    end
    
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD_C;
                    col_idx = 10'd0;
                    zero_count = 10'd0;
                end
            end
            
            LOAD_C: begin
                if (col_idx < N) begin
                    c_mem[col_idx] = c_in;
                    col_idx = col_idx + 10'd1;
                end else begin
                    H_limit = M - c_mem[N - 10'd1];
                    dp_prev[0] = 17'd1;
                    next_state = COMPUTE;
                    col_idx = 10'd1;
                end
            end
            
            COMPUTE: begin
                if (col_idx < N) begin
                    H_max = M - c_mem[col_idx];
                    
                    // Compute dp_curr[0]
                    dp_curr[0] = dp_prev[0];
                    
                    // Compute dp_curr[1..H_max]
                    for (height_idx = 10'd1; height_idx <= H_max; height_idx = height_idx + 10'd1) begin
                        temp_sum = dp_prev[height_idx] + dp_curr[height_idx - 10'd1];
                        if (temp_sum >= 17'd100003) begin
                            dp_curr[height_idx] = temp_sum - 17'd100003;
                        end else begin
                            dp_curr[height_idx] = temp_sum;
                        end
                    end
                    
                    // Count zeros in dp_curr[0..H_max]
                    for (height_idx = 10'd0; height_idx <= H_max; height_idx = height_idx + 10'd1) begin
                        if (dp_curr[height_idx] == 17'd0) begin
                            zero_count = zero_count + 10'd1;
                        end
                    end
                    
                    // Copy dp_curr to dp_prev for next iteration
                    for (height_idx = 10'd0; height_idx <= 1023; height_idx = height_idx + 10'd1) begin
                        dp_prev[height_idx] = dp_curr[height_idx];
                    end
                    
                    col_idx = col_idx + 10'd1;
                end else begin
                    result = dp_prev[H_limit];
                    X = zero_count;
                    next_state = FINISH;
                end
            end
            
            FINISH: begin
                done = 1'b1;
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule