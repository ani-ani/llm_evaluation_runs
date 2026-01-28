module nested_list_sum(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] data [0:15][0:15],
    input wire [3:0] valid_len [0:15],
    output reg signed [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] PROCESS = 3'd1;
    localparam [2:0] FINISH  = 3'd2;

    reg [2:0] state;
    reg [7:0] level_counter;
    reg [7:0] element_counter;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            level_counter <= 8'd0;
            element_counter <= 8'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= PROCESS;
                        level_counter <= 8'd0;
                        element_counter <= 8'd0;
                        result <= 16'd0;
                    end
                end

                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Process current element if valid
                    if (element_counter < valid_len[level_counter] && 
                        data[level_counter][element_counter] != 8'd0) begin
                        result <= result + data[level_counter][element_counter];
                    end

                    // Move to next element
                    element_counter <= element_counter + 8'd1;

                    // Check if done with current level
                    if (element_counter >= valid_len[level_counter]) begin
                        element_counter <= 8'd0;
                        level_counter <= level_counter + 8'd1;

                        // Check if done with all levels
                        if (level_counter >= 8'd16 || cycle_count >= MAX_CYCLES) begin
                            state <= FINISH;
                        end
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