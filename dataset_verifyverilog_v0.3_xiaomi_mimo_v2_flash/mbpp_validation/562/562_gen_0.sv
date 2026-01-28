module max_sublist_length (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] data_in,
    input wire valid_in,
    input wire end_of_sublist,
    input wire end_of_input,
    output reg [7:0] max_length,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] PROCESS    = 3'd1;
    localparam [2:0] UPDATE_MAX = 3'd2;
    localparam [2:0] COMPLETE   = 3'd3;

    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] current_length;
    reg [7:0] max_len_reg;
    reg [2:0] element_count;
    reg [2:0] sublist_count;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = PROCESS;
                else
                    next_state = IDLE;
            end

            PROCESS: begin
                if (valid_in && !end_of_sublist && !end_of_input)
                    next_state = PROCESS;
                else if (end_of_sublist || end_of_input)
                    next_state = UPDATE_MAX;
                else
                    next_state = PROCESS;
            end

            UPDATE_MAX: begin
                if (end_of_input)
                    next_state = COMPLETE;
                else
                    next_state = PROCESS;
            end

            COMPLETE: begin
                next_state = COMPLETE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Output and datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_length <= 8'd0;
            max_len_reg <= 8'd0;
            element_count <= 3'd0;
            sublist_count <= 3'd0;
            done <= 1'b0;
            max_length <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    current_length <= 8'd0;
                    max_len_reg <= 8'd0;
                    element_count <= 3'd0;
                    sublist_count <= 3'd0;
                    done <= 1'b0;
                end

                PROCESS: begin
                    if (valid_in && !end_of_sublist) begin
                        element_count <= element_count + 3'd1;
                    end

                    if (end_of_sublist) begin
                        current_length <= element_count + 3'd1;
                        element_count <= 3'd0;
                        sublist_count <= sublist_count + 3'd1;
                    end else if (end_of_input) begin
                        current_length <= element_count + 3'd1;
                    end
                end

                UPDATE_MAX: begin
                    if (current_length > max_len_reg) begin
                        max_len_reg <= current_length;
                    end
                    current_length <= 8'd0;
                end

                COMPLETE: begin
                    max_length <= max_len_reg;
                    done <= 1'b1;
                end

                default: begin
                    current_length <= 8'd0;
                    max_len_reg <= 8'd0;
                    element_count <= 3'd0;
                    sublist_count <= 3'd0;
                    done <= 1'b0;
                    max_length <= 8'd0;
                end
            endcase
        end
    end

endmodule