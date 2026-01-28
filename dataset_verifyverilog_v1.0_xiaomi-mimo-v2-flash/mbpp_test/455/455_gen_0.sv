module Month31Days (
    input clk,
    input rst_n,
    input start,
    input [3:0] month,
    output reg has_31_days,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd10;
    
    // Combinational lookup for 31-day months
    // Month 0-15: bits 1, 3, 5, 7, 8, 10, 12 are 31-day months
    reg lookup_result;
    
    always @(*) begin
        case (month)
            4'd1:   lookup_result = 1'b1;  // Jan
            4'd3:   lookup_result = 1'b1;  // Mar
            4'd5:   lookup_result = 1'b1;  // May
            4'd7:   lookup_result = 1'b1;  // Jul
            4'd8:   lookup_result = 1'b1;  // Aug
            4'd10:  lookup_result = 1'b1;  // Oct
            4'd12:  lookup_result = 1'b1;  // Dec
            default: lookup_result = 1'b0; // All others including 0,13-15
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            has_31_days <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute result
                    has_31_days <= lookup_result;
                    
                    // Exit after 1 cycle or timeout
                    if (cycle_count >= 8'd0) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule