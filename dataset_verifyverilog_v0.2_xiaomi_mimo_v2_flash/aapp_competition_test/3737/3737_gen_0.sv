module steward_support (
    input clk,
    input rst_n,
    input start,
    input [7:0] strength,
    input [2:0] n,
    output reg [2:0] result,
    output reg done
);

    // Internal storage
    reg [7:0] mem [0:7];
    reg [7:0] min_val;
    reg [7:0] max_val;
    reg [2:0] idx;
    reg [2:0] calc_idx;
    
    // State encoding
    localparam IDLE = 2'b00;
    localparam INPUT = 2'b01;
    localparam CALCULATE = 2'b10;
    localparam DONE = 2'b11;
    
    reg [1:0] state;
    
    // State transition and datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            idx <= 3'b0;
            calc_idx <= 3'b0;
            result <= 3'b0;
            done <= 1'b0;
            min_val <= 8'hFF;
            max_val <= 8'h00;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        idx <= 3'b0;
                        calc_idx <= 3'b0;
                        result <= 3'b0;
                        min_val <= 8'hFF;
                        max_val <= 8'h00;
                        state <= INPUT;
                    end
                end
                
                INPUT: begin
                    if (idx < n) begin
                        mem[idx] <= strength;
                        // Update min/max on the fly
                        if (idx == 3'b0) begin
                            min_val <= strength;
                            max_val <= strength;
                        end else begin
                            if (strength < min_val) min_val <= strength;
                            if (strength > max_val) max_val <= strength;
                        end
                        idx <= idx + 1'b1;
                    end
                    if (idx == n) begin
                        state <= CALCULATE;
                    end
                end
                
                CALCULATE: begin
                    if (calc_idx < n) begin
                        // Check if value is strictly between min and max
                        if (mem[calc_idx] > min_val && mem[calc_idx] < max_val) begin
                            result <= result + 1'b1;
                        end
                        calc_idx <= calc_idx + 1'b1;
                    end else begin
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    if (start) begin
                        // Reset for new computation
                        idx <= 3'b0;
                        calc_idx <= 3'b0;
                        result <= 3'b0;
                        min_val <= 8'hFF;
                        max_val <= 8'h00;
                        done <= 1'b0;
                        state <= INPUT;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule