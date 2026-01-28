module shuffle_count(
    input clk,
    input rst_n,
    input start,
    input [2:0] a [0:7],
    input [2:0] b [0:7],
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMP_A_INV = 3'd1;
    localparam [2:0] COMP_X = 3'd2;
    localparam [2:0] FIND_ORDER = 3'd3;
    localparam [2:0] FIND_D = 3'd4;
    localparam [2:0] COMPUTE_RESULT = 3'd5;
    localparam [2:0] DONE_STATE = 3'd6;

    // Internal registers
    reg [2:0] state;
    reg [2:0] a_inv [0:7];
    reg [2:0] x [0:7];
    reg [2:0] current_power [0:7];
    reg [2:0] next_power [0:7];
    reg [7:0] order;
    reg [7:0] d;
    reg d_found;
    reg [7:0] counter;
    reg [7:0] step_counter;
    reg [7:0] even_candidate;
    reg [7:0] odd_candidate;

    // Constants
    localparam [7:0] INF = 8'd255;
    localparam [7:0] MAX_ITER = 8'd16;

    // Compute inverse of permutation a
    wire [2:0] a_inv_comb [0:7];
    integer i, j;
    always @(*) begin
        for (i = 0; i < 8; i = i + 1) begin
            a_inv_comb[i] = 3'd0;
            for (j = 0; j < 8; j = j + 1) begin
                if (a[j] == i) begin
                    a_inv_comb[i] = j;
                end
            end
        end
    end

    // Compute X = B ∘ A
    wire [2:0] x_comb [0:7];
    always @(*) begin
        for (i = 0; i < 8; i = i + 1) begin
            x_comb[i] = b[a[i]];
        end
    end

    // Compute next_power = X ∘ current_power
    wire [2:0] next_power_comb [0:7];
    always @(*) begin
        for (i = 0; i < 8; i = i + 1) begin
            next_power_comb[i] = x[current_power[i]];
        end
    end

    // Check if permutation is identity
    wire is_identity;
    always @(*) begin
        is_identity = 1'b1;
        for (i = 0; i < 8; i = i + 1) begin
            if (current_power[i] != i) begin
                is_identity = 1'b0;
            end
        end
    end

    // Check if current_power equals a_inv
    wire is_a_inv;
    always @(*) begin
        is_a_inv = 1'b1;
        for (i = 0; i < 8; i = i + 1) begin
            if (current_power[i] != a_inv[i]) begin
                is_a_inv = 1'b0;
            end
        end
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            counter <= 8'd0;
            step_counter <= 8'd0;
            order <= 8'd0;
            d <= 8'd0;
            d_found <= 1'b0;
            even_candidate <= 8'd0;
            odd_candidate <= 8'd0;
            for (i = 0; i < 8; i = i + 1) begin
                a_inv[i] <= 3'd0;
                x[i] <= 3'd0;
                current_power[i] <= 3'd0;
                next_power[i] <= 3'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMP_A_INV;
                    end
                end

                COMP_A_INV: begin
                    for (i = 0; i < 8; i = i + 1) begin
                        a_inv[i] <= a_inv_comb[i];
                    end
                    state <= COMP_X;
                end

                COMP_X: begin
                    for (i = 0; i < 8; i = i + 1) begin
                        x[i] <= x_comb[i];
                    end
                    // Initialize current_power to identity
                    for (i = 0; i < 8; i = i + 1) begin
                        current_power[i] <= i;
                    end
                    counter <= 8'd0;
                    state <= FIND_ORDER;
                end

                FIND_ORDER: begin
                    counter <= counter + 8'd1;
                    // Compute next_power
                    for (i = 0; i < 8; i = i + 1) begin
                        next_power[i] <= next_power_comb[i];
                    end
                    // Check if next_power is identity
                    if (is_identity || counter >= MAX_ITER) begin
                        order <= counter + 8'd1;
                        // Initialize current_power to identity for FIND_D
                        for (i = 0; i < 8; i = i + 1) begin
                            current_power[i] <= i;
                        end
                        step_counter <= 8'd0;
                        d_found <= 1'b0;
                        state <= FIND_D;
                    end else begin
                        // Update current_power
                        for (i = 0; i < 8; i = i + 1) begin
                            current_power[i] <= next_power[i];
                        end
                    end
                end

                FIND_D: begin
                    step_counter <= step_counter + 8'd1;
                    // Compute next_power
                    for (i = 0; i < 8; i = i + 1) begin
                        next_power[i] <= next_power_comb[i];
                    end
                    // Check if current_power equals a_inv
                    if (is_a_inv) begin
                        d <= step_counter;
                        d_found <= 1'b1;
                    end
                    // Check if next_power equals a_inv
                    if (is_a_inv || step_counter >= order || step_counter >= MAX_ITER) begin
                        if (!d_found && is_a_inv) begin
                            d <= step_counter + 8'd1;
                            d_found <= 1'b1;
                        end
                        even_candidate <= 2 * order;
                        odd_candidate <= d_found ? (2 * d + 8'd1) : INF;
                        state <= COMPUTE_RESULT;
                    end else begin
                        // Update current_power
                        for (i = 0; i < 8; i = i + 1) begin
                            current_power[i] <= next_power[i];
                        end
                    end
                end

                COMPUTE_RESULT: begin
                    result <= (even_candidate < odd_candidate) ? even_candidate : odd_candidate;
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule