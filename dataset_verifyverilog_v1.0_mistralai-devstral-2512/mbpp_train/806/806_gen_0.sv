module MaxUppercaseRun(
    input clk,
    input rst_n,
    input start,
    input [7:0] str [0:15],
    output reg [3:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [3:0] index;
    reg [3:0] current_run;
    reg [3:0] max_run;
    reg [7:0] current_char;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            current_run <= 4'd0;
            max_run <= 4'd0;
            result <= 4'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PROCESSING;
                        index <= 4'd0;
                        current_run <= 4'd0;
                        max_run <= 4'd0;
                    end
                end

                PROCESSING: begin
                    current_char = str[index];
                    
                    // Check if current character is uppercase
                    if (current_char >= 8'h41 && current_char <= 8'h5A) begin
                        current_run <= current_run + 4'd1;
                    end else begin
                        // Update max_run when non-uppercase found
                        if (current_run > max_run) begin
                            max_run <= current_run;
                        end
                        current_run <= 4'd0;
                    end
                    
                    // Move to next character
                    if (index == 4'd15) begin
                        // Final update after last character
                        if (current_run > max_run) begin
                            max_run <= current_run;
                        end
                        result <= max_run;
                        state <= DONE_STATE;
                    end else begin
                        index <= index + 4'd1;
                    end
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