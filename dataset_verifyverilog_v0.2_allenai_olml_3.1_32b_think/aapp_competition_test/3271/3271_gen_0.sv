module inversion_counter (
    input clk,
    input rst_n, // active-low reset
    input start,
    input [4:0] N,
    input [7:0] C,
    output reg [31:0] result,
    output reg done
);

// Internal registers
reg [2:0] state; // IDLE=0, INIT=1, COMPUTE_N=2, COMPUTE_C=3, COMPUTE_I=4, DONE=5
reg [4:0] n_count;
reg [7:0] target_N;
reg [7:0] target_C;
reg [31:0] dp_prev [0:255] = 0;
reg [31:0] dp_curr [0:255] = 0;
reg [31:0] sum_val;
reg [7:0] c_count;
reg [3:0] i_count;
reg init_completed;

always @(negedge rst_n) begin
    if (!rst_n) begin
        state <= 3'd0;
        n_count <= 5'd0;
        target_N <= 8'd0;
        target_C <= 8'd0;
        c_count <= 8'd0;
        i_count <= 4'd0;
        sum_val <= 32'd0;
        done <= 1'b0;
        result <= 32'd0;
        init_completed <= 1'b0;
    end
end

always @(posedge clk) begin
    if (!rst_n) begin
        state <= 3'd0;
    end else begin
        case (state)
            3'd0: begin // IDLE
                if (start == 1'b1) begin
                    state <= 3'd1;
                    init_completed <= 1'b0;
                end else begin
                    state <= 3'd0;
                end
            end
            3'd1: begin // INIT
                if (init_completed == 1'b0) begin
                    init_completed <= 1'b1;
                    state <= 3'd1;
                end else begin
                    target_N <= N;
                    target_C <= C;
                    dp_prev[0] <= 32'd1;
                    n_count <= 5'd1;
                    state <= 3'd2;
                end
            end
            3'd2: begin // COMPUTE_N
                if (n_count > target_N) begin
                    state <= 3'd5;
                    done <= 1'b1;
                    result <= 32'd0;
                end else if (n_count < target_N) begin
                    c_count <= 8'd0;
                    i_count <= 4'd0;
                    sum_val <= 32'd0;
                    state <= 3'd3;
                end else begin
                    c_count <= 8'd0;
                    i_count <= 4'd0;
                    sum_val <= 32'd0;
                    state <= 3'd3;
                end
            end
            3'd3: begin // COMPUTE_C
                if (c_count > target_C) begin
                    if (n_count == target_N) begin
                        result <= dp_curr[target_C];
                        done <= 1'b1;
                        state <= 3'd5;
                    end else begin
                        n_count <= n_count + 1;
                        state <= 3'd2;
                    end
                end else begin
                    sum_val <= 32'd0;
                    i_count <= 4'd0;
                    state <= 3'd4;
                end
            end
            3'd4: begin // COMPUTE_I
                localparam int min_val = (c_count < (n_count - 1)) ? c_count : (n_count - 1);
                if (i_count <= min_val) begin
                    sum_val <= sum_val + dp_prev[c_count - i_count];
                    i_count <= i_count + 1;
                    state <= 3'd4;
                end else begin
                    dp_curr[c_count] <= sum_val % 1000000007;
                    i_count <= 4'd0;
                    c_count <= c_count + 1;
                    state <= 3'd3;
                end
            end
            3'd5: begin // DONE
                state <= 3'd5;
                done <= 1'b1;
            end
            default: state <= 3'd0;
        endcase
    end
end
endmodule