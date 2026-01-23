module teacher_rotation (
    input clk,
    input rst_n, // active-low reset
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

// State machine registers
reg [2:0] state;
localparam IDLE = 3'b000;
localparam CAPTURE = 3'b001;
localparam PROCESSING_TYPE0 = 3'b010;
localparam PROCESSING_TYPE1 = 3'b011;
localparam DONE = 3'b100;

reg [3:0] captured_query_type;
reg [3:0] captured_K_in;
reg [3:0] captured_x_in;
reg [3:0] captured_d_in;
reg [3:0] captured_p_in [0:7];

// Teacher-class mapping: 16 weeks, 8 teachers
reg [2:0] class_of_teacher [0:15][0:7];

// Output registers
reg [3:0] result_reg;
reg result_valid_reg;
reg ready_reg;

// Initialize class_of_teacher combinatorially
always @(*) begin
    for (int w=0; w<16; w++) begin
        for (int t=0; t<8; t++) begin
            class_of_teacher[w][t] = t;
        end
    end
end

// State machine and output logic
always @(posedge clk or !rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        captured_query_type <= 0;
        captured_K_in <=0;
        captured_x_in <=0;
        captured_d_in <=0;
        for (int i=0; i<8; i++) begin
            captured_p_in[i] <=0;
        end
        ready_reg <= 1'b1;
        result_reg <=0;
        result_valid_reg <=0;
    end else begin
        case(state)
            IDLE: begin
                if (start) begin
                    state <= CAPTURE;
                    ready_reg <= 1'b0;
                end else begin
                    state <= IDLE;
                    ready_reg <= 1'b1;
                end
            end
            CAPTURE: begin
                captured_query_type <= query_type;
                captured_K_in <= K_in;
                captured_x_in <= x_in;
                captured_d_in <= d_in;
                for (int i=0; i<8; i++) begin
                    captured_p_in[i] <= p_in[i];
                end
                if (captured_query_type == 0) begin
                    state <= PROCESSING_TYPE0;
                end else begin
                    state <= PROCESSING_TYPE1;
                end
                ready_reg <= 1'b0;
            end
            PROCESSING_TYPE0: begin
                // Apply rotation to all weeks >= captured_x_in
                for (int w=captured_x_in; w<16; w++) begin
                    // Read current classes of the K_in teachers
                    reg [2:0] temp_classes [0:7];
                    for (int i=0; i<captured_K_in; i++) begin
                        temp_classes[i] = class_of_teacher[w][ captured_p_in[i] ];
                    end
                    // Rotate right by 1
                    if (captured_K_in > 0) begin
                        for (int i=0; i<captured_K_in; i++) begin
                            int src = (i == captured_K_in -1) ? 0 : i+1;
                            class_of_teacher[w][ captured_p_in[i] ] = temp_classes[src];
                        end
                    end
                end
                state <= DONE;
                ready_reg <= 1'b1;
            end
            PROCESSING_TYPE1: begin
                result_reg <= class_of_teacher[captured_x_in][ captured_d_in ];
                result_valid_reg <= 1'b1;
                state <= DONE;
                ready_reg <= 1'b1;
            end
            DONE: begin
                if (start) begin
                    state <= IDLE;
                end else begin
                    state <= DONE;
                    ready_reg <= 1'b1;
                end
            end
        endcase
    end
end

// Assign outputs
assign result = result_reg;
assign result_valid = result_valid_reg;
assign ready = ready_reg;

endmodule