module InsertElement(
    input clk,
    input rst_n,
    input start,
    input [7:0] element,
    input [7:0] arr_in [0:7],
    input [3:0] len_in,
    output reg [7:0] result [0:15],
    output reg [3:0] len_out,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PROCESS = 3'd1;
    localparam [2:0] FINISH = 3'd2;

    reg [2:0] state, next_state;
    reg [3:0] in_counter;
    reg [3:0] out_counter;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd15;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            len_out <= 4'd0;
            in_counter <= 4'd0;
            out_counter <= 4'd0;
            cycle_count <= 4'd0;
            // Initialize result array
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                result[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESS;
                end
            end
            PROCESS: begin
                if (out_counter == (len_in * 2) || cycle_count >= MAX_CYCLES) begin
                    next_state = FINISH;
                end
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Counter logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            in_counter <= 4'd0;
            out_counter <= 4'd0;
            cycle_count <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    in_counter <= 4'd0;
                    out_counter <= 4'd0;
                    cycle_count <= 4'd0;
                end
                PROCESS: begin
                    cycle_count <= cycle_count + 4'd1;
                    if (out_counter < (len_in * 2)) begin
                        if (out_counter[0] == 1'b0) begin
                            in_counter <= in_counter + 4'd1;
                        end
                        out_counter <= out_counter + 4'd1;
                    end
                end
                FINISH: begin
                    // No action needed
                end
                default: begin
                    in_counter <= 4'd0;
                    out_counter <= 4'd0;
                    cycle_count <= 4'd0;
                end
            endcase
        end
    end

    // Result array generation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                result[i] <= 8'd0;
            end
        end else begin
            if (state == PROCESS && out_counter < (len_in * 2)) begin
                if (out_counter[0] == 1'b0) begin
                    // Insert element
                    result[out_counter] <= element;
                end else begin
                    // Insert arr_in element
                    result[out_counter] <= arr_in[in_counter - 4'd1];
                end
            end
        end
    end

    // Output length and done signal
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            len_out <= 4'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    len_out <= 4'd0;
                    done <= 1'b0;
                end
                PROCESS: begin
                    len_out <= len_in * 2;
                    done <= 1'b0;
                end
                FINISH: begin
                    len_out <= len_in * 2;
                    done <= 1'b1;
                end
                default: begin
                    len_out <= 4'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule