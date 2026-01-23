module leader_determiner#(parameter N=8, parameter M=16) (
    input clk,
    input rst_n,
    input start,
    input [3:0] msg_id,
    input msg_type,
    input msg_valid,
    output reg [N-1:0] possible_leaders,
    output reg done
);

integer idx;

reg [N-1:0] current_status;
reg active_count;
reg [N-1:0] ineligible;
reg [3:0] msg_count;
reg [2:0] state;

reg [3:0] current_msg_id;
reg msg_type_reg;

localparam IDLE = 3'b000;
localparam LOAD_MSG = 3'b001;
localparam PROCESS_MSG = 3'b010;
localparam UPDATE_STATE = 3'b011;
localparam DONE = 3'b100;

always @(posedge clk) begin
    if (!rst_n) begin
        current_status <= 0;
        active_count <=0;
        ineligible <=0;
        msg_count <=0;
        state <= IDLE;
        done <=0;
        current_msg_id <=0;
        msg_type_reg <=0;
    end else begin
        case (state)
            IDLE:  
                if (start) begin
                    state <= LOAD_MSG;
                    msg_count <=0;
                    current_status <=0;
                    active_count <=0;
                    ineligible <=0;
                end
                else begin
                    state <= IDLE;
                end
            LOAD_MSG:  
                if (msg_valid) begin
                    current_msg_id <= msg_id;
                    msg_type_reg <= msg_type;
                    state <= PROCESS_MSG;
                end else begin
                    state <= LOAD_MSG;
                end
            PROCESS_MSG:  
                if (current_msg_id ==0) begin 
                    // invalid message, proceed
                end else begin
                    idx = current_msg_id -1;
                    if (idx >= N) begin 
                        // invalid participant ID, proceed
                    end else begin
                        if (msg_type_reg ==1) begin // log on
                            if (current_status[idx] ==0) begin
                                current_status[idx] <=1;
                                active_count <= active_count +1;
                            end
                        end else begin // log off
                            if (current_status[idx] ==1) begin
                                if (active_count >1) begin
                                    ineligible[idx] <= ineligible[idx] | 1'b1;
                                end
                                current_status[idx] <=0;
                                active_count <= active_count -1;
                            end
                        end
                    end
                end
                state <= UPDATE_STATE;
            UPDATE_STATE: 
                msg_count <= msg_count +1;
                if (msg_count == M) begin
                    done <=1;
                    state <= DONE;
                end else begin
                    state <= LOAD_MSG;
                end
            DONE: 
                state <= DONE;
        endcase
    end
end

assign possible_leaders = ~ineligible;

endmodule