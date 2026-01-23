module parse_nested_parens (
    input clk,
    input rst_n,
    input start,
    input [6:0] char_in,
    input valid,
    input done_in,
    output reg [3:0] result,
    output reg done,
    output reg [2:0] group_count
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam PARSE = 3'b001;
    localparam WAIT_SPACE = 3'b010;
    localparam COMPLETE = 3'b011;

    // ASCII constants
    localparam SPACE = 7'd32;
    localparam OPEN = 7'd40;
    localparam CLOSE = 7'd41;

    reg [2:0] state;
    reg [3:0] depth;
    reg [3:0] group_depth;
    reg [3:0] max_depth;
    reg processed_done;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'b0;
            done <= 1'b0;
            group_count <= 3'b0;
            depth <= 4'b0;
            group_depth <= 4'b0;
            max_depth <= 4'b0;
            processed_done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= PARSE;
                        depth <= 4'b0;
                        group_depth <= 4'b0;
                        max_depth <= 4'b0;
                        group_count <= 3'b0;
                        processed_done <= 1'b0;
                        done <= 1'b0;
                        result <= 4'b0;
                    end
                end

                PARSE: begin
                    if (valid) begin
                        if (char_in == SPACE) begin
                            // Record group depth
                            if (group_depth > max_depth)
                                max_depth <= group_depth;
                            
                            // Increment group count
                            group_count <= group_count + 1;
                            
                            // Reset for next group
                            depth <= 4'b0;
                            group_depth <= 4'b0;
                            
                            state <= WAIT_SPACE;
                        end else if (char_in == OPEN) begin
                            if (depth < 4'd15) begin
                                depth <= depth + 1;
                                if (depth + 1 > group_depth)
                                    group_depth <= depth + 1;
                            end
                        end else if (char_in == CLOSE) begin
                            if (depth > 0)
                                depth <= depth - 1;
                        end
                    end
                    
                    if (done_in && !processed_done) begin
                        processed_done <= 1'b1;
                        // Record last group
                        if (group_depth > max_depth)
                            result <= group_depth;
                        else
                            result <= max_depth;
                        
                        // Increment group count for last group
                        group_count <= group_count + 1;
                        state <= COMPLETE;
                    end
                end

                WAIT_SPACE: begin
                    if (valid) begin
                        if (char_in == SPACE) begin
                            // Stay in wait space (skip consecutive spaces)
                        end else begin
                            // Start of new group
                            state <= PARSE;
                            depth <= 4'b0;
                            group_depth <= 4'b0;
                        end
                    end
                    
                    if (done_in && !processed_done) begin
                        processed_done <= 1'b1;
                        if (group_depth > max_depth)
                            result <= group_depth;
                        else
                            result <= max_depth;
                        group_count <= group_count + 1;
                        state <= COMPLETE;
                    end
                end

                COMPLETE: begin
                    done <= 1'b1;
                    if (!start) begin
                        // Wait for reset or new start
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule