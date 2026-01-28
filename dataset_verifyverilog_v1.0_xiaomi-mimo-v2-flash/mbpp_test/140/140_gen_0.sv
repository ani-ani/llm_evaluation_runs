module FlattenUnique (
    input clk,
    input rst_n,
    input start,
    input [15:0] arr [0:7][0:7],
    input [3:0] len [0:7],
    output reg [15:0] result [0:63],
    output reg [5:0] valid_count,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] RESET_OUT = 3'd1;
    localparam [2:0] PROCESS   = 3'd2;
    localparam [2:0] LOOKUP    = 3'd3;
    localparam [2:0] APPEND    = 3'd4;
    localparam [2:0] FINISH    = 3'd5;
    localparam [2:0] RESET_2   = 3'd6;
    localparam [2:0] RESET_3   = 3'd7;

    reg [2:0] state, next_state;
    reg [2:0] outer_idx;
    reg [2:0] inner_idx;
    reg [5:0] out_idx;
    reg [5:0] lookup_idx;
    reg [5:0] temp_count;
    reg [15:0] current_value;
    reg [15:0] temp_result [0:63];
    reg found;
    reg [7:0] cycle_counter;

    integer i;

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: next_state = start ? RESET_OUT : IDLE;
            RESET_OUT: next_state = RESET_2;
            RESET_2: next_state = RESET_3;
            RESET_3: next_state = PROCESS;
            PROCESS: begin
                if (outer_idx < 8 && inner_idx < 8) begin
                    if (len[outer_idx] == 4'd0) next_state = PROCESS;
                    else if (inner_idx >= len[outer_idx]) next_state = PROCESS;
                    else next_state = LOOKUP;
                end else next_state = FINISH;
            end
            LOOKUP: begin
                if (found || out_idx == 6'd64) next_state = APPEND;
                else next_state = LOOKUP;
            end
            APPEND: next_state = PROCESS;
            FINISH: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            outer_idx <= 3'd0;
            inner_idx <= 3'd0;
            out_idx <= 6'd0;
            lookup_idx <= 6'd0;
            temp_count <= 6'd0;
            current_value <= 16'd0;
            done <= 1'b0;
            found <= 1'b0;
            cycle_counter <= 8'd0;
            valid_count <= 6'd0;
            for (i = 0; i < 64; i = i + 1) begin
                result[i] <= 16'd0;
                temp_result[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
            done <= 1'b0;

            case (state)
                IDLE: begin
                    outer_idx <= 3'd0;
                    inner_idx <= 3'd0;
                    out_idx <= 6'd0;
                    lookup_idx <= 6'd0;
                    temp_count <= 6'd0;
                    current_value <= 16'd0;
                    found <= 1'b0;
                    cycle_counter <= 8'd0;
                end

                RESET_OUT: begin
                    for (i = 0; i < 64; i = i + 1) begin
                        temp_result[i] <= 16'd0;
                    end
                end

                RESET_2: begin
                    // Intentional wait
                end

                RESET_3: begin
                    temp_count <= 6'd0;
                end

                PROCESS: begin
                    if (outer_idx >= 8) begin
                        // Done
                    end else if (len[outer_idx] == 4'd0) begin
                        outer_idx <= outer_idx + 3'd1;
                        inner_idx <= 3'd0;
                    end else if (inner_idx >= len[outer_idx]) begin
                        outer_idx <= outer_idx + 3'd1;
                        inner_idx <= 3'd0;
                    end else begin
                        current_value <= arr[outer_idx][inner_idx];
                        inner_idx <= inner_idx + 3'd1;
                        lookup_idx <= 6'd0;
                        out_idx <= temp_count;
                        found <= 1'b0;
                    end
                    cycle_counter <= cycle_counter + 8'd1;
                end

                LOOKUP: begin
                    if (lookup_idx < temp_count) begin
                        if (temp_result[lookup_idx] == current_value) begin
                            found <= 1'b1;
                        end
                        lookup_idx <= lookup_idx + 6'd1;
                    end
                    cycle_counter <= cycle_counter + 8'd1;
                end

                APPEND: begin
                    if (!found && temp_count < 6'd64) begin
                        temp_result[temp_count] <= current_value;
                        temp_count <= temp_count + 6'd1;
                    end
                end

                FINISH: begin
                    valid_count <= temp_count;
                    done <= 1'b1;
                    for (i = 0; i < 64; i = i + 1) begin
                        result[i] <= temp_result[i];
                    end
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule