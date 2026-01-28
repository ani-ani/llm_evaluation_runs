module dedup_module(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:15],
    input wire [3:0] len,
    output reg [7:0] result [0:15],
    output reg [3:0] out_len,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] PROCESS   = 2'd1;
    localparam [1:0] CHECK     = 2'd2;
    localparam [1:0] FINISH    = 2'd3;

    reg [1:0] state, next_state;
    reg [3:0] in_idx;       // Current input index
    reg [3:0] out_idx;      // Current output index
    reg [3:0] check_idx;    // Index for duplicate checking
    reg [7:0] current_val;  // Current value being processed
    reg found;             // Flag if duplicate found
    reg [7:0] cycle_count; // Prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd255;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            in_idx <= 4'd0;
            out_idx <= 4'd0;
            check_idx <= 4'd0;
            current_val <= 8'd0;
            found <= 1'b0;
            cycle_count <= 8'd0;
            done <= 1'b0;
            out_len <= 4'd0;
            // Initialize result array
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                result[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESS;
                    in_idx = 4'd0;
                    out_idx = 4'd0;
                    cycle_count = 8'd0;
                end
            end

            PROCESS: begin
                if (in_idx < len) begin
                    current_val = arr[in_idx];
                    check_idx = 4'd0;
                    found = 1'b0;
                    next_state = CHECK;
                end else begin
                    next_state = FINISH;
                end
            end

            CHECK: begin
                if (check_idx < in_idx) begin
                    if (arr[check_idx] == current_val) begin
                        found = 1'b1;
                    end
                    check_idx = check_idx + 4'd1;
                end else begin
                    if (!found) begin
                        result[out_idx] = current_val;
                        out_idx = out_idx + 4'd1;
                    end
                    in_idx = in_idx + 4'd1;
                    next_state = PROCESS;
                end
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            out_len <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                end

                PROCESS: begin
                    done <= 1'b0;
                end

                CHECK: begin
                    done <= 1'b0;
                end

                FINISH: begin
                    done <= 1'b1;
                    out_len <= out_idx;
                end

                default: begin
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Safety: prevent infinite loops
    always @(posedge clk) begin
        if (cycle_count >= MAX_CYCLES) begin
            state <= IDLE;
            done <= 1'b1;
            out_len <= out_idx;
            cycle_count <= 8'd0;
        end
    end

endmodule