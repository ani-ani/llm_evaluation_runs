module license_renewal (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [7:0] s1,
    input wire [7:0] s2,
    input wire [7:0] t0,
    input wire [7:0] t1,
    input wire [7:0] t2,
    input wire [7:0] t3,
    input wire [7:0] t4,
    input wire [7:0] t5,
    input wire [7:0] t6,
    input wire [7:0] t7,
    output reg [3:0] max_count,
    output reg done
);
    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] SETUP_SIM = 3'd2;
    localparam [2:0] CHECK_CUSTOMER = 3'd3;
    localparam [2:0] NEXT_ASSIGNMENT = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    reg [2:0] state;
    reg [2:0] next_state;
    reg [8:0] assignment_counter;
    reg [8:0] max_assignment;
    reg [3:0] n_reg;
    reg [7:0] s1_reg, s2_reg;
    reg [7:0] t_reg_0, t_reg_1, t_reg_2, t_reg_3, t_reg_4, t_reg_5, t_reg_6, t_reg_7;
    reg [3:0] customer_index;
    reg [7:0] rem1, rem2;
    reg [3:0] current_count;
    reg [3:0] max_count_reg;
    reg [3:0] iteration_count;
    localparam [3:0] MAX_ITERATIONS = 4'd15;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            assignment_counter <= 9'd0;
            max_assignment <= 9'd0;
            n_reg <= 4'd0;
            s1_reg <= 8'd0;
            s2_reg <= 8'd0;
            t_reg_0 <= 8'd0;
            t_reg_1 <= 8'd0;
            t_reg_2 <= 8'd0;
            t_reg_3 <= 8'd0;
            t_reg_4 <= 8'd0;
            t_reg_5 <= 8'd0;
            t_reg_6 <= 8'd0;
            t_reg_7 <= 8'd0;
            customer_index <= 4'd0;
            rem1 <= 8'd0;
            rem2 <= 8'd0;
            current_count <= 4'd0;
            max_count <= 4'd0;
            max_count_reg <= 4'd0;
            iteration_count <= 4'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    n_reg <= n;
                    s1_reg <= s1;
                    s2_reg <= s2;
                    t_reg_0 <= t0;
                    t_reg_1 <= t1;
                    t_reg_2 <= t2;
                    t_reg_3 <= t3;
                    t_reg_4 <= t4;
                    t_reg_5 <= t5;
                    t_reg_6 <= t6;
                    t_reg_7 <= t7;
                    max_assignment <= (9'd1 << n) - 9'd1;
                    assignment_counter <= 9'd0;
                    max_count_reg <= 4'd0;
                    state <= SETUP_SIM;
                end

                SETUP_SIM: begin
                    customer_index <= 4'd0;
                    rem1 <= s1_reg;
                    rem2 <= s2_reg;
                    current_count <= 4'd0;
                    iteration_count <= 4'd0;
                    state <= CHECK_CUSTOMER;
                end

                CHECK_CUSTOMER: begin
                    if (customer_index >= n_reg) begin
                        if (current_count > max_count_reg) begin
                            max_count_reg <= current_count;
                        end
                        state <= NEXT_ASSIGNMENT;
                    end else if (iteration_count >= MAX_ITERATIONS) begin
                        if (current_count > max_count_reg) begin
                            max_count_reg <= current_count;
                        end
                        state <= NEXT_ASSIGNMENT;
                    end else begin
                        iteration_count <= iteration_count + 4'd1;
                        if (assignment_counter[customer_index] == 1'b0) begin
                            if (customer_index == 4'd0) begin
                                if (t_reg_0 <= rem1) begin
                                    rem1 <= rem1 - t_reg_0;
                                    current_count <= current_count + 4'd1;
                                    customer_index <= customer_index + 4'd1;
                                end else begin
                                    if (current_count > max_count_reg) begin
                                        max_count_reg <= current_count;
                                    end
                                    state <= NEXT_ASSIGNMENT;
                                end
                            end else if (customer_index == 4'd1) begin
                                if (t_reg_1 <= rem1) begin
                                    rem1 <= rem1 - t_reg_1;
                                    current_count <= current_count + 4'd1;
                                    customer_index <= customer_index + 4'd1;
                                end else begin
                                    if (current_count > max_count_reg) begin
                                        max_count_reg <= current_count;
                                    end
                                    state <= NEXT_ASSIGNMENT;
                                end
                            end else if (customer_index == 4'd2) begin
                                if (t_reg_2 <= rem1) begin
                                    rem1 <= rem1 - t_reg_2;
                                    current_count <= current_count + 4'd1;
                                    customer_index <= customer_index + 4'd1;
                                end else begin
                                    if (current_count > max_count_reg) begin
                                        max_count_reg <= current_count;
                                    end
                                    state <= NEXT_ASSIGNMENT;
                                end
                            end else if (customer_index == 4'd3) begin
                                if (t_reg_3 <= rem1) begin
                                    rem1 <= rem1 - t_reg_3;
                                    current_count <= current_count + 4'd1;
                                    customer_index <= customer_index + 4'd1;
                                end else begin
                                    if (current_count > max_count_reg) begin
                                        max_count_reg <= current_count;
                                    end
                                    state <= NEXT_ASSIGNMENT;
                                end
                            end else if (customer_index == 4'd4) begin
                                if (t_reg_4 <= rem1) begin
                                    rem1 <= rem1 - t_reg_4;
                                    current_count <= current_count + 4'd1;
                                    customer_index <= customer_index + 4'd1;
                                end else begin
                                    if (current_count > max_count_reg) begin
                                        max_count_reg <= current_count;
                                    end
                                    state <= NEXT_ASSIGNMENT;
                                end
                            end else if (customer_index == 4'd5) begin
                                if (t_reg_5 <= rem1) begin
                                    rem1 <= rem1 - t_reg_5;
                                    current_count <= current_count + 4'd1;
                                    customer_index <= customer_index + 4'd1;
                                end else begin
                                    if (current_count > max_count_reg) begin
                                        max_count_reg <= current_count;
                                    end
                                    state <= NEXT_ASSIGNMENT;
                                end
                            end else if (customer_index == 4'd6) begin
                                if (t_reg_6 <= rem1) begin
                                    rem1 <= rem1 - t_reg_6;
                                    current_count <= current_count + 4'd1;
                                    customer_index <= customer_index + 4'd1;
                                end else begin
                                    if (current_count > max_count_reg) begin
                                        max_count_reg <= current_count;
                                    end
                                    state <= NEXT_ASSIGNMENT;
                                end
                            end else begin
                                if (t_reg_7 <= rem1) begin
                                    rem1 <= rem1 - t_reg_7;
                                    current_count <= current_count + 4'd1;
                                    customer_index <= customer_index + 4'd1;
                                end else begin
                                    if (current_count > max_count_reg) begin
                                        max_count_reg <= current_count;
                                    end
                                    state <= NEXT_ASSIGNMENT;
                                end
                            end
                        end else begin
                            if (customer_index == 4'd0) begin
                                if (t_reg_0 <= rem2) begin
                                    rem2 <= rem2 - t_reg_0;
                                    current_count <= current_count + 4'd1;
                                    customer_index <= customer_index + 4'd1;
                                end else begin
                                    if (current_count > max_count_reg) begin
                                        max_count_reg <= current_count;
                                    end
                                    state <= NEXT_ASSIGNMENT;
                                end
                            end else if (customer_index == 4'd1) begin
                                if (t_reg_1 <= rem2) begin
                                    rem2 <= rem2 - t_reg_1;
                                    current_count <= current_count + 4'd1;
                                    customer_index <= customer_index + 4'd1;
                                end else begin
                                    if (current_count > max_count_reg) begin
                                        max_count_reg <= current_count;
                                    end
                                    state <= NEXT_ASSIGNMENT;
                                end
                            end else if (customer_index == 4'd2) begin
                                if (t_reg_2 <= rem2) begin
                                    rem2 <= rem2 - t_reg_2;
                                    current_count <= current_count + 4'd1;
                                    customer_index <= customer_index + 4'd1;
                                end else begin
                                    if (current_count > max_count_reg) begin
                                        max_count_reg <= current_count;
                                    end
                                    state <= NEXT_ASSIGNMENT;
                                end
                            end else if (customer_index == 4'd3) begin
                                if (t_reg_3 <= rem2) begin
                                    rem2 <= rem2 - t_reg_3;
                                    current_count <= current_count + 4'd1;
                                    customer_index <= customer_index + 4'd1;
                                end else begin
                                    if (current_count > max_count_reg) begin
                                        max_count_reg <= current_count;
                                    end
                                    state <= NEXT_ASSIGNMENT;
                                end
                            end else if (customer_index == 4'd4) begin
                                if (t_reg_4 <= rem2) begin
                                    rem2 <= rem2 - t_reg_4;
                                    current_count <= current_count + 4'd1;
                                    customer_index <= customer_index + 4'd1;
                                end else begin
                                    if (current_count > max_count_reg) begin
                                        max_count_reg <= current_count;
                                    end
                                    state <= NEXT_ASSIGNMENT;
                                end
                            end else if (customer_index == 4'd5) begin
                                if (t_reg_5 <= rem2) begin
                                    rem2 <= rem2 - t_reg_5;
                                    current_count <= current_count + 4'd1;
                                    customer_index <= customer_index + 4'd1;
                                end else begin
                                    if (current_count > max_count_reg) begin
                                        max_count_reg <= current_count;
                                    end
                                    state <= NEXT_ASSIGNMENT;
                                end
                            end else if (customer_index == 4'd6) begin
                                if (t_reg_6 <= rem2) begin
                                    rem2 <= rem2 - t_reg_6;
                                    current_count <= current_count + 4'd1;
                                    customer_index <= customer_index + 4'd1;
                                end else begin
                                    if (current_count > max_count_reg) begin
                                        max_count_reg <= current_count;
                                    end
                                    state <= NEXT_ASSIGNMENT;
                                end
                            end else begin
                                if (t_reg_7 <= rem2) begin
                                    rem2 <= rem2 - t_reg_7;
                                    current_count <= current_count + 4'd1;
                                    customer_index <= customer_index + 4'd1;
                                end else begin
                                    if (current_count > max_count_reg) begin
                                        max_count_reg <= current_count;
                                    end
                                    state <= NEXT_ASSIGNMENT;
                                end
                            end
                        end
                    end
                end

                NEXT_ASSIGNMENT: begin
                    if (assignment_counter + 9'd1 <= max_assignment) begin
                        assignment_counter <= assignment_counter + 9'd1;
                        state <= SETUP_SIM;
                    end else begin
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    max_count <= max_count_reg;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule