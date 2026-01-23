module teacher_rotation (
    input clk,
    input rst_n,
    input start,
    input [2:0] query_type,
    input [3:0] K_in,
    input [3:0] x_in,
    input [3:0] d_in,
    input [3:0] p_in [0:7],
    output reg [3:0] result,
    output reg result_valid,
    output reg ready
);

    // Parameters
    parameter M = 16; // Max weeks
    parameter N = 8;  // Max teachers/classes
    parameter LOG_M = 4; // log2(M)
    parameter LOG_N = 3; // log2(N)

    // State Memory: class_of_teacher[week][teacher] -> class
    // We use two arrays to support pipelined updates or simpler logic.
    // However, due to the requirement of processing sequentially and updating weeks >= x,
    // we will use a single storage array and an update state machine.
    reg [2:0] class_of_teacher [0:M-1][0:N-1];

    // Validity tracking to avoid resetting memory explicitly if not needed,
    // but reset is required. We will use a valid bit array for weeks to know if initialized.
    reg week_valid [0:M-1];

    // FSM States
    localparam IDLE = 3'b000;
    localparam UPDATE_START = 3'b001; // Prepare for update loop
    localparam UPDATE_LOOP = 3'b010; // Perform update for specific week
    localparam UPDATE_NEXT = 3'b011; // Move to next week
    localparam QUERY_START = 3'b100; // Prepare query output
    localparam WAIT_READY = 3'b101;  // Wait for start to go low

    reg [2:0] state;
    reg [2:0] next_state;

    // Temporary registers for iteration
    reg [3:0] current_week;
    reg [3:0] current_teacher;
    reg [2:0] p_reg [0:7]; // Local copy of rotation teachers
    reg [3:0] K_reg;       // Local copy of K
    reg [2:0] query_teacher;
    reg [3:0] query_week;
    reg [2:0] temp_class;  // Storage for swap operation

    integer i, j;

    // State Transition and Output Logic (Sequential)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            ready <= 1'b1;
            result_valid <= 1'b0;
            result <= 4'b0;
            // Reset memory (implicitly handles the initial state)
            for (i = 0; i < M; i = i + 1) begin
                week_valid[i] <= 1'b0;
            end
        end else begin
            case (state)
                IDLE: begin
                    result_valid <= 1'b0;
                    if (start) begin
                        ready <= 1'b0;
                        if (query_type == 3'b0) begin
                            // Type 0: Rotation
                            // Copy inputs to local regs
                            K_reg <= (K_in > 4'd8) ? 4'd8 : K_in;
                            for (int k = 0; k < 8; k++) begin
                                if (k < K_in && k < 8)
                                    p_reg[k] <= p_in[k][2:0];
                                else
                                    p_reg[k] <= 3'b0;
                            end
                            current_week <= x_in;
                            if (x_in >= M) begin
                                // If week is out of range, just finish immediately
                                state <= WAIT_READY;
                            end else begin
                                state <= UPDATE_START;
                            end
                        end else begin
                            // Type 1: Query
                            query_teacher <= d_in[2:0];
                            query_week <= x_in;
                            state <= QUERY_START;
                        end
                    end
                end

                UPDATE_START: begin
                    // Ensure week memory is initialized if not already
                    if (!week_valid[current_week]) begin
                        // Initialize this week based on previous week (or initial identity)
                        // Week 0 is identity. If current_week > 0, copy from previous.
                        if (current_week == 0) begin
                            for (int t = 0; t < N; t++) begin
                                class_of_teacher[0][t] <= t;
                            end
                        end else begin
                            // Copy from previous week (assumed valid)
                            for (int t = 0; t < N; t++) begin
                                class_of_teacher[current_week][t] <= class_of_teacher[current_week-1][t];
                            end
                        end
                        week_valid[current_week] <= 1'b1;
                        current_teacher <= 0;
                        state <= UPDATE_LOOP;
                    end else begin
                        // Already valid, proceed to updates
                        current_teacher <= 0;
                        state <= UPDATE_LOOP;
                    end
                end

                UPDATE_LOOP: begin
                    // Perform rotation for teacher current_teacher
                    // We need to check if current_teacher is in p_reg
                    // Search linearly in p_reg (max 8)
                    if (current_teacher < N) begin
                        // Check match
                        logic match;
                        match = 1'b0;
                        for (int k = 0; k < 8; k++) begin
                            if (k < K_reg && p_reg[k] == current_teacher) begin
                                match = 1'b1;
                            end
                        end

                        if (match) begin
                            // Swap class with next teacher in p_reg circularly
                            // Find position in p_reg
                            logic found;
                            found = 1'b0;
                            for (int k = 0; k < 8; k++) begin
                                if (!found && k < K_reg && p_reg[k] == current_teacher) begin
                                    // Next index in p_reg
                                    logic [2:0] next_idx;
                                    if (k == K_reg - 1) next_idx = p_reg[0];
                                    else next_idx = p_reg[k+1];
                                    
                                    // Swap
                                    class_of_teacher[current_week][current_teacher] <= class_of_teacher[current_week][next_idx];
                                    class_of_teacher[current_week][next_idx] <= class_of_teacher[current_week][current_teacher];
                                    found = 1'b1;
                                end
                            end
                        end
                        current_teacher <= current_teacher + 1;
                        state <= UPDATE_LOOP;
                    end else begin
                        state <= UPDATE_NEXT;
                    end
                end

                UPDATE_NEXT: begin
                    current_week <= current_week + 1;
                    if (current_week + 1 >= M) begin
                        state <= WAIT_READY;
                    end else begin
                        state <= UPDATE_START;
                    end
                end

                QUERY_START: begin
                    // Ensure query week is initialized
                    if (!week_valid[query_week]) begin
                        // Initialize chain if needed (lazy init)
                        // We assume if week is invalid, we must init from 0 up to query_week
                        // However, strictly: If week >= M, output 0 or handle error.
                        // If week < M but uninitialized, it implies no updates happened for that week.
                        // In strict logic, uninitialized means identity.
                        // But to be safe and consistent with updates, we perform lazy init.
                        // Since we can't loop back easily in one cycle, we'll just set identity for this specific week if it was never touched.
                        // OR, simpler: If not valid, it's identity.
                        // Let's just output the query based on current memory state.
                        // If never written, it contains X or 0. We should initialize.
                        // Let's initialize just this week if needed.
                        if (query_week == 0) begin
                            for (int t = 0; t < N; t++) class_of_teacher[0][t] <= t;
                        end else begin
                            // If prev week valid, copy. If not, assume identity (or recurse? No, assume identity for simplicity of HW)
                            // Actually, if week_valid is false, it means NO updates happened up to this point. So Identity.
                            for (int t = 0; t < N; t++) begin
                                class_of_teacher[query_week][t] <= t;
                            end
                        end
                        week_valid[query_week] <= 1'b1;\                    end
                    state <= WAIT_READY;
                    result <= {1'b0, class_of_teacher[query_week][query_teacher]};
                    result_valid <= 1'b1;
                end

                WAIT_READY: begin
                    if (!start) begin
                        state <= IDLE;
                        ready <= 1'b1;
                    end else begin
                        // Stay here until start goes low
                        state <= WAIT_READY;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
