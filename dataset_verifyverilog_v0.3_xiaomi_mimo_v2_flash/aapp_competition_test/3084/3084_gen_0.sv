module clock_setting (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] orig_time_h,
    input wire [7:0] orig_time_m,
    input wire [7:0] target_time_h,
    input wire [7:0] target_time_m,
    output reg [7:0] current_time_h,
    output reg [7:0] current_time_m,
    output reg valid,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE                  = 3'd0;
    localparam [2:0] CHANGE_MINUTE_ONES    = 3'd1;
    localparam [2:0] CHANGE_MINUTE_TENS    = 3'd2;
    localparam [2:0] CHANGE_HOUR_ONES      = 3'd3;
    localparam [2:0] CHANGE_HOUR_TENS      = 3'd4;
    localparam [2:0] FINISHED              = 3'd5;

    reg [2:0] state;
    reg [2:0] next_state;
    
    // Current values being adjusted
    reg [7:0] current_h;
    reg [7:0] current_m;
    reg [7:0] target_h;
    reg [7:0] target_m;
    
    // Helper: increment digit with wrap
    function [3:0] inc_digit;
        input [3:0] digit;
        begin
            if (digit == 4'd9)
                inc_digit = 4'd0;
            else
                inc_digit = digit + 4'd1;
        end
    endfunction
    
    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_h <= 8'd0;
            current_m <= 8'd0;
            target_h <= 8'd0;
            target_m <= 8'd0;
            valid <= 1'b0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        current_h <= orig_time_h;
                        current_m <= orig_time_m;
                        target_h <= target_time_h;
                        target_m <= target_time_m;
                        valid <= 1'b1;
                        done <= 1'b0;
                    end else begin
                        valid <= 1'b0;
                    end
                end
                
                CHANGE_MINUTE_ONES: begin
                    if (current_m[3:0] != target_m[3:0]) begin
                        current_m[3:0] <= inc_digit(current_m[3:0]);
                        if ((current_h < 8'd24) && (current_m < 8'd60)) begin
                            valid <= 1'b1;
                        end else begin
                            valid <= 1'b0;
                        end
                    end else begin
                        valid <= 1'b0;
                    end
                end
                
                CHANGE_MINUTE_TENS: begin
                    if (current_m[7:4] != target_m[7:4]) begin
                        current_m[7:4] <= inc_digit(current_m[7:4]);
                        if ((current_h < 8'd24) && (current_m < 8'd60)) begin
                            valid <= 1'b1;
                        end else begin
                            valid <= 1'b0;
                        end
                    end else begin
                        valid <= 1'b0;
                    end
                end
                
                CHANGE_HOUR_ONES: begin
                    if (current_h[3:0] != target_h[3:0]) begin
                        current_h[3:0] <= inc_digit(current_h[3:0]);
                        if ((current_h < 8'd24) && (current_m < 8'd60)) begin
                            valid <= 1'b1;
                        end else begin
                            valid <= 1'b0;
                        end
                    end else begin
                        valid <= 1'b0;
                    end
                end
                
                CHANGE_HOUR_TENS: begin
                    if (current_h[7:4] != target_h[7:4]) begin
                        current_h[7:4] <= inc_digit(current_h[7:4]);
                        if ((current_h < 8'd24) && (current_m < 8'd60)) begin
                            valid <= 1'b1;
                        end else begin
                            valid <= 1'b0;
                        end
                    end else begin
                        valid <= 1'b0;
                    end
                end
                
                FINISHED: begin
                    done <= 1'b1;
                    valid <= 1'b0;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
            
            state <= next_state;
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CHANGE_MINUTE_ONES;
                end
            end
            
            CHANGE_MINUTE_ONES: begin
                if (current_m[3:0] == target_m[3:0]) begin
                    next_state = CHANGE_MINUTE_TENS;
                end
            end
            
            CHANGE_MINUTE_TENS: begin
                if (current_m[7:4] == target_m[7:4]) begin
                    next_state = CHANGE_HOUR_ONES;
                end
            end
            
            CHANGE_HOUR_ONES: begin
                if (current_h[3:0] == target_h[3:0]) begin
                    next_state = CHANGE_HOUR_TENS;
                end
            end
            
            CHANGE_HOUR_TENS: begin
                if (current_h[7:4] == target_h[7:4]) begin
                    next_state = FINISHED;
                end
            end
            
            FINISHED: begin
                next_state = FINISHED;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Output assignments
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_time_h <= 8'd0;
            current_time_m <= 8'd0;
        end else begin
            current_time_h <= current_h;
            current_time_m <= current_m;
        end
    end

endmodule