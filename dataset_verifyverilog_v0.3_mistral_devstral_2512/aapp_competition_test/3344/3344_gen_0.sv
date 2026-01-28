module luggage_speed(
    input clk,
    input rst_n,
    input start,
    input [7:0] pos [0:3],
    input [2:0] num_luggage,
    input [7:0] L,
    output reg [15:0] v,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] LATCH = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] FINISH = 2'd3;
    
    localparam [7:0] MAX_CYCLES = 8'd1000;
    localparam [7:0] K_MAX = 8'd10;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    
    reg [2:0] latched_num_luggage;
    reg [7:0] latched_L;
    reg [7:0] latched_pos [0:3];
    
    reg [1:0] i;
    reg [1:0] j;
    reg [7:0] k;
    
    reg [15:0] global_min;
    reg [15:0] global_max;
    
    reg [15:0] current_a;
    reg [15:0] current_b;
    
    reg [15:0] temp_d;
    reg [15:0] temp_denom1;
    reg [15:0] temp_denom2;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 8'd0;
            v <= 16'd0;
            done <= 1'b0;
            
            i <= 2'd0;
            j <= 2'd0;
            k <= 8'd0;
            
            global_min <= 16'd1024;
            global_max <= 16'd10240;
            
            latched_num_luggage <= 3'd0;
            latched_L <= 8'd0;
            
            integer idx;
            for (idx = 0; idx < 4; idx = idx + 1) begin
                latched_pos[idx] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= LATCH;
                    end
                end
                
                LATCH: begin
                    latched_num_luggage <= num_luggage;
                    latched_L <= L;
                    
                    integer idx;
                    for (idx = 0; idx < 4; idx = idx + 1) begin
                        latched_pos[idx] <= pos[idx];
                    end
                    
                    i <= 2'd0;
                    j <= 2'd1;
                    k <= 8'd0;
                    
                    global_min <= 16'd1024;
                    global_max <= 16'd10240;
                    
                    state <= COMPUTE;
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end else begin
                        if (i < latched_num_luggage) begin
                            if (j < latched_num_luggage) begin
                                if (i < j) begin
                                    temp_d <= {8'd0, latched_pos[i] - latched_pos[j]};
                                    if (temp_d[15]) begin
                                        temp_d <= {8'd0, latched_pos[j] - latched_pos[i]};
                                    end
                                    
                                    temp_denom1 <= {8'd0, k * latched_L + latched_L - 1};
                                    temp_denom2 <= {8'd0, k * latched_L + 1};
                                    
                                    current_a <= fixed_div(temp_d, temp_denom1);
                                    current_b <= fixed_div(temp_d, temp_denom2);
                                    
                                    if (current_a > global_min) begin
                                        global_min <= current_a;
                                    end
                                    if (current_b < global_max) begin
                                        global_max <= current_b;
                                    end
                                    
                                    if (k < K_MAX) begin
                                        k <= k + 8'd1;
                                    end else begin
                                        k <= 8'd0;
                                        j <= j + 2'd1;
                                    end
                                end else begin
                                    j <= j + 2'd1;
                                end
                            end else begin
                                j <= 2'd0;
                                i <= i + 2'd1;
                            end
                        end else begin
                            state <= FINISH;
                        end
                    end
                end
                
                FINISH: begin
                    if (global_min < global_max) begin
                        v <= global_max;
                    end else begin
                        v <= 16'd0;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    function [15:0] fixed_div(input [15:0] numerator, input [15:0] denominator);
        reg [15:0] quotient;
        reg [15:0] remainder;
        reg [15:0] abs_numerator;
        reg [15:0] abs_denominator;
        reg [15:0] result;
        reg [7:0] i;
        
        abs_numerator = numerator;
        abs_denominator = denominator;
        
        if (abs_numerator[15]) begin
            abs_numerator = ~abs_numerator + 16'd1;
        end
        
        if (abs_denominator[15]) begin
            abs_denominator = ~abs_denominator + 16'd1;
        end
        
        quotient = 16'd0;
        remainder = 16'd0;
        
        for (i = 0; i < 16; i = i + 1) begin
            remainder = {remainder[14:0], abs_numerator[15]};
            abs_numerator = {abs_numerator[14:0], 1'b0};
            
            if (remainder >= abs_denominator) begin
                remainder = remainder - abs_denominator;
                quotient[15] = 1'b1;
            end else begin
                quotient[15] = 1'b0;
            end
            
            quotient = {quotient[14:0], 1'b0};
        end
        
        result = quotient;
        
        if (numerator[15] ^ denominator[15]) begin
            result = ~result + 16'd1;
        end
        
        fixed_div = result;
    endfunction
    
endmodule