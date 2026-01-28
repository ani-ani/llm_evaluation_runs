module distinct_char_counter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] str [0:7],
    output reg [4:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] PROCESS = 3'd1;
    localparam [2:0] FINISH  = 3'd2;

    reg [2:0] state;
    reg [4:0] cycle_count;
    localparam [4:0] MAX_CYCLES = 5'd20;

    // Array to track seen characters (26 letters)
    reg [25:0] seen;
    reg [4:0] char_count;
    reg [4:0] i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 5'd0;
            done <= 1'b0;
            cycle_count <= 5'd0;
            seen <= 26'd0;
            char_count <= 5'd0;
            i <= 5'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 5'd0;
                    if (start) begin
                        state <= PROCESS;
                        seen <= 26'd0;
                        char_count <= 5'd0;
                        i <= 5'd0;
                    end
                end

                PROCESS: begin
                    cycle_count <= cycle_count + 5'd1;

                    // Process one character per cycle
                    if (i < 5'd8) begin
                        reg [7:0] current_char;
                        current_char = str[i];

                        // Convert to lowercase by clearing bit 5
                        reg [7:0] lower_char;
                        lower_char = current_char & 8'hDF;

                        // Check if it's a letter (a-z or A-Z)
                        if ((lower_char >= 8'h41) && (lower_char <= 8'h5A)) begin
                            reg [4:0] char_index;
                            char_index = lower_char - 8'h41;

                            // Mark as seen if not already
                            if (!seen[char_index]) begin
                                seen[char_index] <= 1'b1;
                                char_count <= char_count + 5'd1;
                            end
                        end

                        i <= i + 5'd1;
                    end

                    // Exit conditions
                    if ((i >= 5'd8) || (cycle_count >= MAX_CYCLES)) begin
                        state <= FINISH;
                        result <= char_count;
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