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

    // State declarations
    localparam [3:0] 
        IDLE            = 4'd0,
        SCAN_CHECK_1    = 4'd1,
        COG_INIT        = 4'd2,
        COG_START       = 4'd3,
        COG_WAIT        = 4'd4,
        CHECK_OVERALL   = 4'd5,
        FMS_INIT        = 4'd6,
        FMS_LOOP_I      = 4'd7,
        FMS_LOOP_J      = 4'd8,
        FMS_COMP_GCD    = 4'd9,
        FMS_COMP_GCD_WAIT= 4'd10,
        COMPUTE_RESULT  = 4'd11,
        DONE_STATE      = 4'd12;
    
    reg [3:0] state;
    
    // Control registers
    reg [WIDTH-1:0] current_gcd;
    reg [WIDTH-1:0] overall_gcd;
    reg [RESULT_WIDTH-1:0] count_ones;
    reg found_one;
    reg [3:0] k;
    reg [3:0] i, j;
    reg [3:0] m;
    reg [RESULT_WIDTH-1:0] min_len;
    
    // GCD unit interface
    reg gcd_start;
    reg [WIDTH-1:0] gcd_a;
    reg [WIDTH-1:0] gcd_b;
    wire [WIDTH-1:0] gcd_result;
    wire gcd_done;
    
    gcd #(.WIDTH(WIDTH)) gcd_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(gcd_start),
        .a(gcd_a),
        .b(gcd_b),
        .gcd(gcd_result),
        .done(gcd_done)
    );
    
    // Array element selector
    function [WIDTH-1:0] get_element(input [3:0] idx);
        get_element = arr[idx * WIDTH +: WIDTH];
    endfunction
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 0;
            done <= 1'b0;
            count_ones <= 0;
            found_one <= 1'b0;
            current_gcd <= 0;
            overall_gcd <= 0;
            k <= 0;
            i <= 0;
            j <= 0;
            m <= 0;
            min_len <= {RESULT_WIDTH{1'b1}};
            gcd_start <= 1'b0;
            gcd_a <= 0;
            gcd_b <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= SCAN_CHECK_1;
                        count_ones <= 0;
                        found_one <= 1'b0;
                        k <= 0;
                    end
                end
                
                SCAN_CHECK_1: begin
                    if (get_element(k) == WIDTH'd1) begin
                        count_ones <= count_ones + 1;
                        found_one <= 1'b1;
                    end
                    
                    if (k == (N-1)) begin
                        state <= COG_INIT;
                        k <= 1;
                        current_gcd <= get_element(0);
                    end else begin
                        k <= k + 1;
                    end
                end
                
                COG_INIT: begin
                    gcd_a <= current_gcd;
                    gcd_b <= get_element(k);
                    gcd_start <= 1'b1;
                    state <= COG_START;
                end
                
                COG_START: begin
                    gcd_start <= 1'b0;
                    state <= COG_WAIT;
                end
                
                COG_WAIT: begin
                    if (gcd_done) begin
                        current_gcd <= gcd_result;
                        if (k == (N-1)) begin
                            overall_gcd <= gcd_result;
                            state <= CHECK_OVERALL;
                        end else begin
                            k <= k + 1;
                            gcd_a <= gcd_result;
                            gcd_b <= get_element(k);
                            gcd_start <= 1'b1;
                            state <= COG_START;
                        end
                    end
                end
                
                CHECK_OVERALL: begin
                    if (overall_gcd != WIDTH'd1) begin
                        result <= {RESULT_WIDTH{1'b1}};
                        state <= DONE_STATE;
                    end else if (found_one) begin
                        result <= N - count_ones;
                        state <= DONE_STATE;
                    end else begin
                        state <= FMS_INIT;
                        min_len <= N+1;
                    end
                end
                
                FMS_INIT: begin
                    i <= 0;
                    state <= FMS_LOOP_I;
                end
                
                FMS_LOOP_I: begin
                    if (i >= N) begin
                        state <= COMPUTE_RESULT;
                    end else begin
                        j <= i;
                        state <= FMS_LOOP_J;
                    end
                end
                
                FMS_LOOP_J: begin
                    if (j >= N) begin
                        i <= i + 1;
                        state <= FMS_LOOP_I;
                    end else begin
                        if (i == j) begin
                            if (get_element(i) == WIDTH'd1) begin
                                min_len <= (1 < min_len) ? 1 : min_len;
                            end
                            j <= j + 1;
                        end else begin
                            m <= i + 1;
                            gcd_a <= get_element(i);
                            gcd_b <= get_element(m);
                            gcd_start <= 1'b1;
                            state <= FMS_COMP_GCD;
                        end
                    end
                end
                
                FMS_COMP_GCD: begin
                    gcd_start <= 1'b0;
                    state <= FMS_COMP_GCD_WAIT;
                end
                
                FMS_COMP_GCD_WAIT: begin
                    if (gcd_done) begin
                        if (gcd_result == WIDTH'd1) begin
                            if ((j - i + 1) < min_len) begin
                                min_len <= j - i + 1;
                            end
                            j <= N; // Break j loop early
                            state <= FMS_LOOP_J;
                        end else if (m < j) begin
                            m <= m + 1;
                            gcd_a <= gcd_result;
                            gcd_b <= get_element(m);
                            gcd_start <= 1'b1;
                            state <= FMS_COMP_GCD;
                        end else begin
                            j <= j + 1;
                            state <= FMS_LOOP_J;
                        end
                    end
                end
                
                COMPUTE_RESULT: begin
                    if (min_len > N) begin
                        result <= {RESULT_WIDTH{1'b1}};
                    end else begin
                        result <= (min_len - 1) + (N - 1);
                    end
                    state <= DONE_STATE;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
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
            busy <= 1'b0;
            done <= 1'b0;
            gcd <= {WIDTH{1'b0}};
        end else begin
            done <= 1'b0;
            
            if (start && !busy) begin
                x <= a;
                y <= b;
                busy <= 1'b1;
            end else if (busy) begin
                if (y != 0) begin
                    x <= y;
                    y <= x % y;
                    done <= 1'b0;
                end else begin
                    gcd <= x;
                    done <= 1'b1;
                    busy <= 1'b0;
                end
            end
        end
    end
endmodule