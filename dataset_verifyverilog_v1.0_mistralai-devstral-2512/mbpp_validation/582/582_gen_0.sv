module dictionary_checker(
    input clk,
    input rst_n,
    input start,
    input [7:0] key,
    input [7:0] value,
    input [1:0] op,
    output reg result,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE      = 4'd0;
    localparam [3:0] CHECK     = 4'd1;
    localparam [3:0] INSERT    = 4'd2;
    localparam [3:0] REMOVE    = 4'd3;
    localparam [3:0] CLEAR     = 4'd4;
    localparam [3:0] FINISH    = 4'd5;

    // Dictionary memory (16 entries)
    reg [7:0] dict_mem [0:15];
    reg dict_valid [0:15];

    // State and control signals
    reg [3:0] state;
    reg [3:0] index;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd16;

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            index <= 4'd0;
            cycle_count <= 4'd0;

            // Initialize dictionary
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                dict_valid[i] <= 1'b0;
                dict_mem[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    index <= 4'd0;
                    cycle_count <= 4'd0;

                    if (start) begin
                        case (op)
                            2'd0: state <= CHECK;
                            2'd1: state <= INSERT;
                            2'd2: state <= REMOVE;
                            2'd3: state <= CLEAR;
                            default: state <= IDLE;
                        endcase
                    end
                end

                CHECK: begin
                    cycle_count <= cycle_count + 4'd1;

                    // Check current entry
                    if (dict_valid[index]) begin
                        result <= 1'b0;  // Found valid entry
                    end

                    // Move to next entry
                    if (index == 4'd15) begin
                        result <= 1'b1;  // All entries checked, still empty
                        state <= FINISH;
                    end else begin
                        index <= index + 4'd1;
                    end

                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end

                INSERT: begin
                    dict_mem[key[3:0]] <= value;
                    dict_valid[key[3:0]] <= 1'b1;
                    state <= FINISH;
                end

                REMOVE: begin
                    dict_valid[key[3:0]] <= 1'b0;
                    state <= FINISH;
                end

                CLEAR: begin
                    integer i;
                    for (i = 0; i < 16; i = i + 1) begin
                        dict_valid[i] <= 1'b0;
                    end
                    state <= FINISH;
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