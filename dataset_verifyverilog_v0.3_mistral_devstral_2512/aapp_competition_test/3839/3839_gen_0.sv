module knight_placement(
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    output reg [7:0] x,
    output reg [7:0] y,
    output reg [7:0] index,
    output reg valid,
    output reg done
);

// Internal registers
reg [7:0] groups;
reg [7:0] remainder;
reg [7:0] group_counter;
reg [1:0] step_counter;
reg [7:0] count;
reg [2:0] state;

// State definitions
localparam [2:0] IDLE = 3'd0;
localparam [2:0] OUTPUT = 3'd1;

// Combinational logic for groups and remainder
always @(*) begin
    if (n <= 8'd3) begin
        groups = (n >= 8'd1) ? 8'd1 : 8'd0;
        remainder = n - (groups * 8'd3);
    end else if (n <= 8'd6) begin
        groups = 8'd2;
        remainder = n - 8'd6;
    end else if (n <= 8'd9) begin
        groups = 8'd3;
        remainder = n - 8'd9;
    end else if (n <= 8'd12) begin
        groups = 8'd4;
        remainder = n - 8'd12;
    end else if (n <= 8'd15) begin
        groups = 8'd5;
        remainder = n - 8'd15;
    end else if (n <= 8'd16) begin
        groups = 8'd5;
        remainder = n - 8'd15;
    end else begin
        groups = 8'd0;
        remainder = 8'd0;
    end
end

// State machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        x <= 8'd0;
        y <= 8'd0;
        index <= 8'd0;
        valid <= 1'b0;
        done <= 1'b0;
        count <= 8'd0;
        group_counter <= 8'd0;
        step_counter <= 2'd0;
    end else begin
        case (state)
            IDLE: begin
                valid <= 1'b0;
                done <= 1'b0;
                count <= 8'd0;
                group_counter <= 8'd0;
                step_counter <= 2'd0;
                if (start && n != 8'd0) begin
                    state <= OUTPUT;
                end
            end

            OUTPUT: begin
                if (count < n) begin
                    valid <= 1'b1;
                    index <= count;
                    
                    if (group_counter < groups) begin
                        // Group phase
                        case (step_counter)
                            2'd0: begin
                                x <= 2 * group_counter;
                                y <= 8'd0;
                            end
                            2'd1: begin
                                x <= 2 * group_counter + 1;
                                y <= 8'd0;
                            end
                            2'd2: begin
                                x <= 2 * group_counter + 1;
                                y <= 8'd3;
                            end
                        endcase
                        
                        step_counter <= step_counter + 1;
                        if (step_counter == 2'd2) begin
                            group_counter <= group_counter + 1;
                            step_counter <= 2'd0;
                        end
                    end else begin
                        // Remainder phase
                        x <= 2 * groups + (count - 3 * groups);
                        y <= 8'd0;
                    end
                    
                    count <= count + 1;
                end else begin
                    valid <= 1'b0;
                    done <= 1'b1;
                    state <= IDLE;
                end
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule