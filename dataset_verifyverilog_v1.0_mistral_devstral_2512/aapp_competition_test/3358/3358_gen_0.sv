module sequential_processor(
    input clk,
    input rst_n,
    input start,
    input [7:0] N,
    output reg [7:0] instruction,
    output reg valid,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] OUTPUT = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    // Instruction opcodes
    localparam [2:0] ST = 3'd0;  // Store
    localparam [2:0] ZE = 3'd1;  // Zero
    localparam [2:0] PH = 3'd2;  // Push
    localparam [2:0] PL = 3'd3;  // Pull
    localparam [2:0] AD = 3'd4;  // Add
    localparam [2:0] DI = 3'd5;  // Divide

    // Register encodings
    localparam [1:0] A = 2'd0;
    localparam [1:0] X = 2'd1;
    localparam [1:0] Y = 2'd2;

    // Program lengths
    localparam [7:0] PROG_LEN_0 = 8'd2;
    localparam [7:0] PROG_LEN_1 = 8'd2;
    localparam [7:0] PROG_LEN_2 = 8'd10;
    localparam [7:0] PROG_LEN_5 = 8'd10;
    localparam [7:0] PROG_LEN_DEFAULT = 8'd2;

    reg [1:0] state;
    reg [7:0] instr_count;
    reg [7:0] prog_len;

    // Instruction memory (pre-defined programs)
    reg [7:0] prog_0 [0:1];
    reg [7:0] prog_1 [0:1];
    reg [7:0] prog_2 [0:9];
    reg [7:0] prog_5 [0:9];
    reg [7:0] prog_default [0:1];

    // Initialize programs
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all registers
            state <= IDLE;
            instruction <= 8'd0;
            valid <= 1'b0;
            done <= 1'b0;
            instr_count <= 8'd0;
            prog_len <= 8'd0;

            // Initialize program memories
            prog_0[0] <= {ZE, Y, 3'd0};
            prog_0[1] <= {DI, Y, 3'd0};

            prog_1[0] <= {ST, Y, 3'd0};
            prog_1[1] <= {DI, Y, 3'd0};

            prog_2[0] <= {ST, Y, 3'd0};
            prog_2[1] <= {ZE, X, 3'd0};
            prog_2[2] <= {PH, X, 3'd0};
            prog_2[3] <= {PL, A, 3'd0};
            prog_2[4] <= {AD, 2'd0, 3'd0};
            prog_2[5] <= {ST, Y, 3'd0};
            prog_2[6] <= {ZE, X, 3'd0};
            prog_2[7] <= {PH, X, 3'd0};
            prog_2[8] <= {PL, A, 3'd0};
            prog_2[9] <= {DI, 2'd0, 3'd0};

            prog_5[0] <= {ST, Y, 3'd0};
            prog_5[1] <= {ZE, X, 3'd0};
            prog_5[2] <= {PH, X, 3'd0};
            prog_5[3] <= {PL, A, 3'd0};
            prog_5[4] <= {AD, 2'd0, 3'd0};
            prog_5[5] <= {ST, Y, 3'd0};
            prog_5[6] <= {ZE, X, 3'd0};
            prog_5[7] <= {PH, X, 3'd0};
            prog_5[8] <= {PL, A, 3'd0};
            prog_5[9] <= {DI, 2'd0, 3'd0};

            prog_default[0] <= {ZE, Y, 3'd0};
            prog_default[1] <= {DI, Y, 3'd0};
        end else begin
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        // Select program based on N
                        case (N)
                            8'd0: begin
                                prog_len <= PROG_LEN_0;
                                instr_count <= 8'd0;
                            end
                            8'd1: begin
                                prog_len <= PROG_LEN_1;
                                instr_count <= 8'd0;
                            end
                            8'd2: begin
                                prog_len <= PROG_LEN_2;
                                instr_count <= 8'd0;
                            end
                            8'd5: begin
                                prog_len <= PROG_LEN_5;
                                instr_count <= 8'd0;
                            end
                            default: begin
                                prog_len <= PROG_LEN_DEFAULT;
                                instr_count <= 8'd0;
                            end
                        endcase
                        state <= OUTPUT;
                    end
                end

                OUTPUT: begin
                    valid <= 1'b1;
                    done <= 1'b0;
                    // Output current instruction
                    case (N)
                        8'd0: instruction <= prog_0[instr_count];
                        8'd1: instruction <= prog_1[instr_count];
                        8'd2: instruction <= prog_2[instr_count];
                        8'd5: instruction <= prog_5[instr_count];
                        default: instruction <= prog_default[instr_count];
                    endcase

                    // Increment counter
                    instr_count <= instr_count + 8'd1;

                    // Check if done
                    if (instr_count == prog_len - 8'd1) begin
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    valid <= 1'b0;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    valid <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule