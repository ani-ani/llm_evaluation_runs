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
    localparam [2:0] IDLE = 3'b000;
    localparam [2:0] INIT = 3'b001;
    localparam [2:0] SETUP_SIM = 3'b010;
    localparam [2:0] CHECK_CUSTOMER = 3'b011;
    localparam [2:0] NEXT_ASSIGNMENT = 3'b100;
    localparam [2:0] DONE = 3'b101;

    reg [2:0] state;
    reg [8:0] assignment_counter;
    reg [8:0] max_assignment;
    reg [3:0] n_reg;
    reg [7:0] s1_reg, s2_reg;
    reg [7:0] t_reg [0:7];
    reg [3:0] customer_index;
    reg [7:0] rem1, rem2;
    reg [3:0] current_count;
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            assignment_counter <= 9'd0;
            max_assignment <= 9'd0;
            n_reg <= 4'd0;
            s1_reg <= 8'd0;
            s2_reg <= 8'd0;
            for (i = 0; i < 8; i = i + 1) begin
                t_reg[i] <= 8'd0;
            end
            customer_index <= 4'd0;
            rem1 <= 8'd0;
            rem2 <= 8'd0;
            current_count <= 4'd0;
            max_count <= 4'd0;
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
                    t_reg[0] <= t0;
                    t_reg[1] <= t1;
                    t_reg[2] <= t2;
                    t_reg[3] <= t3;
                    t_reg[4] <= t4;
                    t_reg[5] <= t5;
                    t_reg[6] <= t6;
                    t_reg[7] <= t7;
                    max_assignment <= (9'd1 << n_reg) - 9'd1;
                    assignment_counter <= 9'd0;
                    max_count <= 4'd0;
                    state <= SETUP_SIM;
                end

                SETUP_SIM: begin
                    rem1 <= s1_reg;
                    rem2 <= s2_reg;
                    customer_index <= 4'd0;
                    current_count <= 4'd0;
                    state <= CHECK_CUSTOMER;
                end

                CHECK_CUSTOMER: begin
                    if (customer_index >= n_reg) begin
                        if (current_count > max_count) begin
                            max_count <= current_count;
                        end
                        state <= NEXT_ASSIGNMENT;
                    end else begin
                        if (assignment_counter[customer_index] == 1'b0) begin
                            if (t_reg[customer_index] <= rem1) begin
                                rem1 <= rem1 - t_reg[customer_index];
                                current_count <= current_count + 4'd1;
                                customer_index <= customer_index + 4'd1;
                            end else begin
                                if (current_count > max_count) begin
                                    max_count <= current_count;
                                end
                                state <= NEXT_ASSIGNMENT;
                            end
                        end else begin
                            if (t_reg[customer_index] <= rem2) begin
                                rem2 <= rem2 - t_reg[customer_index];
                                current_count <= current_count + 4'd1;
                                customer_index <= customer_index + 4'd1;
                            end else begin
                                if (current_count > max_count) begin
                                    max_count <= current_count;
                                end
                                state <= NEXT_ASSIGNMENT;
                            end
                        end
                    end
                end

                NEXT_ASSIGNMENT: begin
                    if (assignment_counter < max_assignment) begin
                        assignment_counter <= assignment_counter + 9'd1;
                        state <= SETUP_SIM;
                    end else begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule