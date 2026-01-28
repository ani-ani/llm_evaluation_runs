module fruit_parser (
    input clk,
    input rst_n,
    input start,
    input [7:0] str [0:31],
    input [7:0] total,
    output reg [7:0] mango,
    output reg done
);

    // ASCII constants
    localparam [7:0] ASCII_0 = 8'd48;
    localparam [7:0] ASCII_9 = 8'd57;
    localparam [7:0] ASCII_a = 8'd97;
    localparam [7:0] ASCII_d = 8'd100;
    localparam [7:0] ASCII_n = 8'd110;
    localparam [7:0] ASCII_o = 8'd111;
    localparam [7:0] ASCII_p = 8'd112;
    localparam [7:0] ASCII_s = 8'd115;

    // States
    localparam [2:0] IDLE          = 3'd0;
    localparam [2:0] SCAN_APPLES   = 3'd1;
    localparam [2:0] SKIP_TO_AND   = 3'd2;
    localparam [2:0] SCAN_ORANGES  = 3'd3;
    localparam [2:0] COMPUTE       = 3'd4;
    localparam [2:0] FINISH        = 3'd5;

    reg [2:0] state, next_state;
    reg [7:0] apples, oranges;
    reg [7:0] apples_sum, oranges_sum;
    reg [7:0] mango_reg;
    reg [5:0] idx;
    reg [2:0] scan_state;
    reg [7:0] temp_val;
    reg [7:0] temp_val_next;
    reg valid;
    reg [7:0] cycle_counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            apples <= 8'd0;
            oranges <= 8'd0;
            mango_reg <= 8'd0;
            done <= 1'b0;
            idx <= 6'd0;
            scan_state <= 3'd0;
            temp_val <= 8'd0;
            valid <= 1'b0;
            cycle_counter <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    apples <= 8'd0;
                    oranges <= 8'd0;
                    temp_val <= 8'd0;
                    valid <= 1'b0;
                    cycle_counter <= 8'd0;
                    if (start) begin
                        state <= SCAN_APPLES;
                        idx <= 6'd0;
                        scan_state <= 3'd0;
                    end
                end

                SCAN_APPLES: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    if (cycle_counter >= 8'd120) begin
                        state <= COMPUTE;
                    end else begin
                        case (scan_state)
                            3'd0: begin // Skip leading chars
                                if (str[idx] >= ASCII_0 && str[idx] <= ASCII_9) begin
                                    temp_val <= str[idx] - ASCII_0;
                                    scan_state <= 3'd1;
                                end
                                idx <= idx + 6'd1;
                            end
                            3'd1: begin // Accumulate digits
                                if (str[idx] >= ASCII_0 && str[idx] <= ASCII_9) begin
                                    temp_val <= (temp_val * 8'd10) + (str[idx] - ASCII_0);
                                    idx <= idx + 6'd1;
                                end else begin
                                    apples <= temp_val;
                                    state <= SKIP_TO_AND;
                                    scan_state <= 3'd0;
                                end
                            end
                            default: scan_state <= 3'd0;
                        endcase
                    end
                end

                SKIP_TO_AND: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    if (cycle_counter >= 8'd120) begin
                        state <= COMPUTE;
                    end else begin
                        case (scan_state)
                            3'd0: begin // Look for 'a'
                                if (str[idx] == ASCII_a) begin
                                    scan_state <= 3'd1;
                                end
                                idx <= idx + 6'd1;
                            end
                            3'd1: begin // Check for 'n'
                                if (str[idx] == ASCII_n) begin
                                    scan_state <= 3'd2;
                                end else begin
                                    scan_state <= 3'd0;
                                end
                                idx <= idx + 6'd1;
                            end
                            3'd2: begin // Check for 'd'
                                if (str[idx] == ASCII_d) begin
                                    scan_state <= 3'd3;
                                end else begin
                                    scan_state <= 3'd0;
                                end
                                idx <= idx + 6'd1;
                            end
                            3'd3: begin // Skip to digit
                                if (str[idx] >= ASCII_0 && str[idx] <= ASCII_9) begin
                                    temp_val <= str[idx] - ASCII_0;
                                    scan_state <= 3'd4;
                                end
                                idx <= idx + 6'd1;
                            end
                            3'd4: begin // Done with AND
                                state <= SCAN_ORANGES;
                                scan_state <= 3'd0;
                            end
                            default: scan_state <= 3'd0;
                        endcase
                    end
                end

                SCAN_ORANGES: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    if (cycle_counter >= 8'd120) begin
                        state <= COMPUTE;
                    end else begin
                        case (scan_state)
                            3'd0: begin // Accumulate digits
                                if (str[idx] >= ASCII_0 && str[idx] <= ASCII_9) begin
                                    temp_val <= (temp_val * 8'd10) + (str[idx] - ASCII_0);
                                    idx <= idx + 6'd1;
                                end else begin
                                    oranges <= temp_val;
                                    state <= COMPUTE;
                                end
                            end
                            default: scan_state <= 3'd0;
                        endcase
                    end
                end

                COMPUTE: begin
                    if (total < apples) begin
                        apples_sum <= 8'd0;
                    end else begin
                        apples_sum <= total - apples;
                    end
                    
                    if (apples_sum < oranges) begin
                        mango_reg <= 8'd0;
                    end else begin
                        mango_reg <= apples_sum - oranges;
                    end
                    state <= FINISH;
                end

                FINISH: begin
                    done <= 1'b1;
                    mango <= mango_reg;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule