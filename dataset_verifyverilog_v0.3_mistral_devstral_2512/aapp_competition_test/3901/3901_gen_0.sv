module min_ops_to_one #(
    parameter N = 8,
    parameter WIDTH = 16,
    parameter RESULT_WIDTH = 16
)(
    input clk,
    input rst_n,
    input start,
    input [N*WIDTH-1:0] arr,
    output reg [RESULT_WIDTH-1:0] result,
    output reg done
);
    
    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SCAN_CHECK_1 = 3'd1;
    localparam [2:0] CHECK_GCD = 3'd2;
    localparam [2:0] FIND_MIN_SUBARRAY = 3'd3;
    localparam [2:0] COMPUTE_RESULT = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;
    
    reg [2:0] state, next_state;
    reg [3:0] i, j;
    reg [WIDTH-1:0] current_gcd, overall_gcd, min_len, temp_gcd;
    reg found_one;
    reg gcd_start;
    wire [WIDTH-1:0] gcd_result;
    wire gcd_done;
    reg [3:0] count_ones;
    reg [3:0] k;
    
    gcd #(.WIDTH(WIDTH)) gcd_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(gcd_start),
        .a(current_gcd),
        .b(temp_gcd),
        .gcd(gcd_result),
        .done(gcd_done)
    );
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            count_ones <= 4'd0;
            current_gcd <= 16'd0;
            overall_gcd <= 16'd0;
            min_len <= 16'd0;
            temp_gcd <= 16'd0;
            found_one <= 1'b0;
            gcd_start <= 1'b0;
        end else begin
            state <= next_state;
        end
    end
    
    always @(*) begin
        next_state = state;
        gcd_start = 1'b0;
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    next_state = SCAN_CHECK_1;
                end
            end
            
            SCAN_CHECK_1: begin
                if (k < N) begin
                    if (arr[k*WIDTH +: WIDTH] == 16'd1) begin
                        count_ones <= count_ones + 4'd1;
                        found_one <= 1'b1;
                    end
                    k <= k + 4'd1;
                end else begin
                    k <= 4'd0;
                    if (found_one) begin
                        next_state = COMPUTE_RESULT;
                    end else begin
                        next_state = CHECK_GCD;
                    end
                end
            end
            
            CHECK_GCD: begin
                if (i < N) begin
                    if (i == 4'd0) begin
                        current_gcd <= arr[i*WIDTH +: WIDTH];
                        i <= i + 4'd1;
                    end else begin
                        temp_gcd <= arr[i*WIDTH +: WIDTH];
                        gcd_start <= 1'b1;
                        next_state = CHECK_GCD;
                    end
                end else begin
                    i <= 4'd0;
                    overall_gcd <= gcd_result;
                    if (overall_gcd != 16'd1) begin
                        result <= 16'd65535;
                        next_state = DONE_STATE;
                    end else begin
                        next_state = FIND_MIN_SUBARRAY;
                    end
                end
            end
            
            FIND_MIN_SUBARRAY: begin
                if (i < N) begin
                    if (j < N) begin
                        if (i == j) begin
                            current_gcd <= arr[i*WIDTH +: WIDTH];
                            j <= j + 4'd1;
                        end else begin
                            temp_gcd <= arr[j*WIDTH +: WIDTH];
                            gcd_start <= 1'b1;
                            next_state = FIND_MIN_SUBARRAY;
                        end
                    end else begin
                        j <= 4'd0;
                        if (gcd_result == 16'd1) begin
                            if (min_len == 16'd0 || (j - i) < min_len) begin
                                min_len <= j - i;
                            end
                        end
                        i <= i + 4'd1;
                    end
                end else begin
                    i <= 4'd0;
                    next_state = COMPUTE_RESULT;
                end
            end
            
            COMPUTE_RESULT: begin
                if (found_one) begin
                    result <= N - count_ones;
                end else begin
                    result <= (min_len - 16'd1) + (N - 16'd1);
                end
                next_state = DONE_STATE;
            end
            
            DONE_STATE: begin
                done <= 1'b1;
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_gcd <= 16'd0;
        end else begin
            if (gcd_done) begin
                current_gcd <= gcd_result;
            end
        end
    end
    
endmodule

module gcd #(
    parameter WIDTH = 16
)(
    input clk,
    input rst_n,
    input start,
    input [WIDTH-1:0] a,
    input [WIDTH-1:0] b,
    output reg [WIDTH-1:0] gcd,
    output reg done
);
    
    reg busy;
    reg [WIDTH-1:0] x, y;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy <= 0;
            done <= 0;
            gcd <= 0;
        end else begin
            if (start && !busy) begin
                x <= a;
                y <= b;
                busy <= 1;
                done <= 0;
            end else if (busy) begin
                if (y != 0) begin
                    x <= y;
                    y <= x % y;
                end else begin
                    gcd <= x;
                    done <= 1;
                    busy <= 0;
                end
            end else begin
                done <= 0;
            end
        end
    end
    
endmodule