module EventDreamScenarioChecker(
    input clk,
    input rst_n,
    input start,
    input [1:0] op_type,
    input [19:0] arg1,
    input [19:0] arg2,
    input [19:0] arg3,
    input [19:0] arg4,
    output reg done,
    output reg [1:0] status,
    output reg [15:0] dream_depth
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] OP_READ = 3'd1;
    localparam [2:0] OP_DREAM = 3'd2;
    localparam [2:0] OP_SCENARIO_START = 3'd3;
    localparam [2:0] OP_SCENARIO_CHECK = 3'd4;
    localparam [2:0] OP_SCENARIO_DREAM = 3'd5;
    localparam [2:0] DONE = 3'd6;

    reg [2:0] state, next_state;

    // Event RAM (256 entries, 20 bits each)
    reg [19:0] event_ram [0:255];
    reg [7:0] event_ram_valid [0:255];

    // History Stack (512 entries, 16 bits each)
    reg [15:0] history_stack [0:511];
    reg [8:0] sp;
    reg [8:0] saved_sp;

    // Scenario Buffer (16 entries, 21 bits each)
    reg [20:0] scenario_buffer [0:15];
    reg [3:0] scenario_count;
    reg [3:0] scenario_index;

    // Operation parameters
    reg [19:0] current_arg1;
    reg [19:0] current_arg2;
    reg [19:0] current_arg3;
    reg [19:0] current_arg4;

    // Dream fallback parameters
    reg [8:0] dream_r;
    reg [8:0] dream_r_max;

    // Status flags
    reg scenario_error;
    reg scenario_dream_found;

    // Cycle counter for timeout
    reg [10:0] cycle_count;
    localparam [10:0] MAX_CYCLES = 11'd2048;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            done <= 1'b0;
            status <= 2'd0;
            dream_depth <= 16'd0;
            sp <= 9'd0;
            saved_sp <= 9'd0;
            scenario_count <= 4'd0;
            scenario_index <= 4'd0;
            current_arg1 <= 20'd0;
            current_arg2 <= 20'd0;
            current_arg3 <= 20'd0;
            current_arg4 <= 20'd0;
            dream_r <= 9'd0;
            dream_r_max <= 9'd0;
            scenario_error <= 1'b0;
            scenario_dream_found <= 1'b0;
            cycle_count <= 11'd0;

            // Initialize event_ram
            integer i;
            for (i = 0; i < 256; i = i + 1) begin
                event_ram[i] <= 20'd0;
                event_ram_valid[i] <= 1'b0;
            end

            // Initialize history_stack
            for (i = 0; i < 512; i = i + 1) begin
                history_stack[i] <= 16'd0;
            end

            // Initialize scenario_buffer
            for (i = 0; i < 16; i = i + 1) begin
                scenario_buffer[i] <= 21'd0;
            end
        end else begin
            state <= next_state;
            done <= 1'b0;

            case (state)
                IDLE: begin
                    if (start) begin
                        current_arg1 <= arg1;
                        current_arg2 <= arg2;
                        current_arg3 <= arg3;
                        current_arg4 <= arg4;
                        next_state <= OP_READ;
                        cycle_count <= 11'd0;
                    end
                end

                OP_READ: begin
                    case (op_type)
                        2'd0: next_state <= OP_DREAM;  // Event
                        2'd1: next_state <= OP_DREAM;  // Dream
                        2'd2: next_state <= OP_SCENARIO_START;  // Scenario
                        default: next_state <= IDLE;
                    endcase
                end

                OP_DREAM: begin
                    if (op_type == 2'd0) begin  // Event
                        // Store event in history stack
                        history_stack[sp] <= current_arg1[15:0];
                        sp <= sp + 9'd1;
                        // Mark event as valid in RAM
                        event_ram_valid[current_arg1[7:0]] <= 1'b1;
                        event_ram[current_arg1[7:0]] <= current_arg1[19:0];
                        status <= 2'd0;  // Yes
                        next_state <= DONE;
                    end else if (op_type == 2'd1) begin  // Dream
                        // Pop r events from stack
                        integer i;
                        for (i = 0; i < current_arg1[8:0]; i = i + 1) begin
                            if (sp > 0) begin
                                sp <= sp - 9'd1;
                                event_ram_valid[history_stack[sp][7:0]] <= 1'b0;
                            end
                        end
                        status <= 2'd0;  // Yes
                        next_state <= DONE;
                    end
                end

                OP_SCENARIO_START: begin
                    // Unpack scenario buffer
                    integer i;
                    for (i = 0; i < 16; i = i + 1) begin
                        if (i < 20) begin
                            scenario_buffer[i] <= {current_arg2[i], current_arg1[19:0]};
                        end else if (i < 40) begin
                            scenario_buffer[i] <= {current_arg3[i-20], current_arg1[19:0]};
                        end else if (i < 60) begin
                            scenario_buffer[i] <= {current_arg4[i-40], current_arg1[19:0]};
                        end
                    end
                    scenario_count <= current_arg1[4:0];
                    scenario_index <= 4'd0;
                    scenario_error <= 1'b0;
                    next_state <= OP_SCENARIO_CHECK;
                end

                OP_SCENARIO_CHECK: begin
                    if (scenario_index < scenario_count) begin
                        // Check current scenario event
                        reg [7:0] event_id = scenario_buffer[scenario_index][19:0];
                        reg negated = scenario_buffer[scenario_index][20];

                        if (negated == 1'b0) begin
                            // Event must exist
                            if (event_ram_valid[event_id] == 1'b0) begin
                                scenario_error <= 1'b1;
                            end
                        end else begin
                            // Event must not exist
                            if (event_ram_valid[event_id] == 1'b1) begin
                                scenario_error <= 1'b1;
                            end
                        end

                        scenario_index <= scenario_index + 4'd1;
                    end else begin
                        if (scenario_error == 1'b1) begin
                            // Check dream fallback
                            saved_sp <= sp;
                            dream_r <= 9'd1;
                            dream_r_max <= sp;
                            scenario_dream_found <= 1'b0;
                            next_state <= OP_SCENARIO_DREAM;
                        end else begin
                            // Scenario valid
                            status <= 2'd0;  // Yes
                            next_state <= DONE;
                        end
                    end
                end

                OP_SCENARIO_DREAM: begin
                    if (dream_r <= dream_r_max) begin
                        // Check scenario with dream_r
                        reg [8:0] temp_sp = saved_sp - dream_r;
                        reg scenario_valid = 1'b1;
                        integer i;

                        for (i = 0; i < scenario_count; i = i + 1) begin
                            reg [7:0] event_id = scenario_buffer[i][19:0];
                            reg negated = scenario_buffer[i][20];
                            reg event_exists = 1'b0;

                            // Check if event exists in RAM excluding last dream_r entries
                            if (event_ram_valid[event_id] == 1'b1) begin
                                integer j;
                                for (j = temp_sp; j < saved_sp; j = j + 1) begin
                                    if (history_stack[j][7:0] == event_id) begin
                                        event_exists = 1'b1;
                                    end
                                end
                            end

                            if (negated == 1'b0) begin
                                // Event must exist
                                if (event_exists == 1'b0) begin
                                    scenario_valid = 1'b0;
                                end
                            end else begin
                                // Event must not exist
                                if (event_exists == 1'b1) begin
                                    scenario_valid = 1'b0;
                                end
                            end
                        end

                        if (scenario_valid == 1'b1) begin
                            scenario_dream_found <= 1'b1;
                            dream_depth <= dream_r[15:0];
                            status <= 2'd1;  // Just A Dream
                            next_state <= DONE;
                        end else begin
                            dream_r <= dream_r + 9'd1;
                        end
                    end else begin
                        // No dream fallback found
                        status <= 2'd2;  // Plot Error
                        next_state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase

            // Cycle counter for timeout
            if (state != IDLE && state != DONE) begin
                cycle_count <= cycle_count + 11'd1;
                if (cycle_count >= MAX_CYCLES) begin
                    next_state <= IDLE;
                    done <= 1'b1;
                    status <= 2'd2;  // Plot Error on timeout
                end
            end
        end
    end

endmodule