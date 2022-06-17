module SW #(parameter WIDTH_SCORE = 8, parameter WIDTH_POS_REF = 7, parameter WIDTH_POS_QUERY = 6)
(
    input           clk,
    input           reset,
    input           valid,
    input [1:0]     data_ref,
    input [1:0]     data_query,
    output          finish,
    output [WIDTH_SCORE - 1:0]   max,
    output [WIDTH_POS_REF - 1:0]   pos_ref,
    output [WIDTH_POS_QUERY - 1:0]   pos_query
);

//------------------------------------------------------------------
// parameter
//------------------------------------------------------------------
parameter match = 2;
parameter mismatch = -1;
parameter g_open = 2;
parameter g_extend = 1;
parameter IDLE = 2'd0; 
parameter READ = 2'd1; 
parameter CAL = 2'd2; 
parameter READY = 2'd3; 

integer i, j;

//------------------------------------------------------------------
// reg & wire
//------------------------------------------------------------------





reg  signed [7:0]  D_PE_r[0:15];
reg  signed [7:0]  D_PE_w[0:15];
reg  signed [7:0]  I_PE_r[0:15];
reg  signed [7:0]  I_PE_w[0:15];
reg  signed [7:0]  H_PE_r[0:15];
reg  signed [7:0]  H_PE_w[0:15];

reg         [6:0]  index_i[15:0], index_i_nxt[15:0];    // num = 64
reg         [5:0]  index_j[15:0], index_j_nxt[15:0];    // num = 48 
reg         [2:0]  state, state_nxt;
reg         [6:0]  counter_R, counter_R_nxt; // num = 64
reg         [5:0]  counter_Q, counter_Q_nxt; // num = 48
reg         [7:0]  counter_cal, counter_cal_nxt; // num = 16*12 = 192


// input FF
reg                valid_r, valid_w;
reg         [1:0]  data_ref_r, data_ref_w;
reg         [1:0]  data_query_r, data_query_w;
reg         [1:0]  R[64:0];
reg         [1:0]  R_nxt_r, R_nxt_w;
reg         [1:0]  Q[48:0];
reg         [1:0]  Q_nxt_r, Q_nxt_w;


// output FF
reg  signed [WIDTH_SCORE - 1:0]       max_r, max_w;
reg         [WIDTH_POS_REF - 1:0]     pos_ref_r, pos_ref_w;
reg         [WIDTH_POS_QUERY - 1:0]   pos_query_r, pos_query_w; 
reg                                   finish_r, finish_w;

reg [1:0] PE_Q[15:0], PE_R[15:0];
reg [7:0] PE_H_S[15:0], PE_H_V[15:0], PE_H_H[15:0], PE_I_V[15:0], PE_D_H[15:0];
reg signed [7:0] H_out[15:0], H_out_previous[15:0];
reg signed [7:0] I_out[15:0], D_out[15:0], H_last[64:0], I_last[64:0];
// wires
wire [7:0] H[15:0], D[15:0], I[15:0];

assign      finish = finish_r;
assign      max = max_r;
assign      pos_ref = pos_ref_r;
assign      pos_query = pos_query_r;


//------------------------------------------------------------------
// submodule
//------------------------------------------------------------------


    always @(*) begin
        case (state)
            IDLE: begin
                if (!reset) 
                    state_nxt = READ;
                else 
                    state_nxt = IDLE;
            end
            READ: begin
                if (counter_R == 64 && counter_Q == 48) begin // The last item is read
                    state_nxt = CAL;
                    // $display("The next state is CAL lalalalalalalalalalala");
                end
                else
                    state_nxt = READ;
            end
            CAL: begin
                if (counter_cal == 192)
                    state_nxt = READY;
                else 
                    state_nxt = CAL;
            end
            READY: begin
                state_nxt = IDLE;
            end
            default: state_nxt = state; // The next state is default to be the current state

        endcase
    
    end

//------------------------------------------------------------------
// combinational part
//------------------------------------------------------------------

    always @(*) begin
        

        case (state)
            READ: begin
                if (valid_r) begin
                    if (counter_R < 64) begin
                        counter_R_nxt = counter_R + 1;
                        R_nxt_w = data_ref_r;
                        // $display("counter_R_nxt = %d", counter_R_nxt);
                    end
                    else begin
                        counter_R_nxt = counter_R;
                        R_nxt_w = R_nxt_r;
                    end
                
                    if (counter_Q < 48) begin
                        counter_Q_nxt = counter_Q + 1;
                        Q_nxt_w = data_query_r;
                        // $display("counter_Q = %d", counter_Q);
                    end
                    else begin
                        counter_Q_nxt = counter_Q;
                        Q_nxt_w = Q_nxt_r;
                    end
                end
                else begin
                    counter_R_nxt = counter_R;
                    counter_Q_nxt = counter_Q;
                    R_nxt_w = R_nxt_r;
                    Q_nxt_w = Q_nxt_r;
                end

            end
            default begin
                counter_R_nxt = counter_R;
                counter_Q_nxt = counter_Q;
                R_nxt_w = R_nxt_r;
                Q_nxt_w = Q_nxt_r;
            end
        endcase
    end
    

    // submodules
    PE PE1(.query(PE_Q[0]), .ref(PE_R[0]), .H_lu(PE_H_S[0]), .H_l(PE_H_H[0]), .H_u(PE_H_V[0]), .I_u(PE_I_V[0]), .D_l(PE_D_H[0]), .H(H[0]), .I(I[0]), .D(D[0]), .clk(clk));
    PE PE2(.query(PE_Q[1]), .ref(PE_R[1]), .H_lu(PE_H_S[1]), .H_l(PE_H_H[1]), .H_u(PE_H_V[1]), .I_u(PE_I_V[1]), .D_l(PE_D_H[1]), .H(H[1]), .I(I[1]), .D(D[1]), .clk(clk));
    PE PE3(.query(PE_Q[2]), .ref(PE_R[2]), .H_lu(PE_H_S[2]), .H_l(PE_H_H[2]), .H_u(PE_H_V[2]), .I_u(PE_I_V[2]), .D_l(PE_D_H[2]), .H(H[2]), .I(I[2]), .D(D[2]), .clk(clk));
    PE PE4(.query(PE_Q[3]), .ref(PE_R[3]), .H_lu(PE_H_S[3]), .H_l(PE_H_H[3]), .H_u(PE_H_V[3]), .I_u(PE_I_V[3]), .D_l(PE_D_H[3]), .H(H[3]), .I(I[3]), .D(D[3]), .clk(clk));
    PE PE5(.query(PE_Q[4]), .ref(PE_R[4]), .H_lu(PE_H_S[4]), .H_l(PE_H_H[4]), .H_u(PE_H_V[4]), .I_u(PE_I_V[4]), .D_l(PE_D_H[4]), .H(H[4]), .I(I[4]), .D(D[4]), .clk(clk));
    PE PE6(.query(PE_Q[5]), .ref(PE_R[5]), .H_lu(PE_H_S[5]), .H_l(PE_H_H[5]), .H_u(PE_H_V[5]), .I_u(PE_I_V[5]), .D_l(PE_D_H[5]), .H(H[5]), .I(I[5]), .D(D[5]), .clk(clk));
    PE PE7(.query(PE_Q[6]), .ref(PE_R[6]), .H_lu(PE_H_S[6]), .H_l(PE_H_H[6]), .H_u(PE_H_V[6]), .I_u(PE_I_V[6]), .D_l(PE_D_H[6]), .H(H[6]), .I(I[6]), .D(D[6]), .clk(clk));
    PE PE8(.query(PE_Q[7]), .ref(PE_R[7]), .H_lu(PE_H_S[7]), .H_l(PE_H_H[7]), .H_u(PE_H_V[7]), .I_u(PE_I_V[7]), .D_l(PE_D_H[7]), .H(H[7]), .I(I[7]), .D(D[7]), .clk(clk));
    PE PE9(.query(PE_Q[8]), .ref(PE_R[8]), .H_lu(PE_H_S[8]), .H_l(PE_H_H[8]), .H_u(PE_H_V[8]), .I_u(PE_I_V[8]), .D_l(PE_D_H[8]), .H(H[8]), .I(I[8]), .D(D[8]), .clk(clk));
    PE PE10(.query(PE_Q[9]), .ref(PE_R[9]), .H_lu(PE_H_S[9]), .H_l(PE_H_H[9]), .H_u(PE_H_V[9]), .I_u(PE_I_V[9]), .D_l(PE_D_H[9]), .H(H[9]), .I(I[9]), .D(D[9]), .clk(clk));
    PE PE11(.query(PE_Q[10]), .ref(PE_R[10]), .H_lu(PE_H_S[10]), .H_l(PE_H_H[10]), .H_u(PE_H_V[10]), .I_u(PE_I_V[10]), .D_l(PE_D_H[10]), .H(H[10]), .I(I[10]), .D(D[10]), .clk(clk));
    PE PE12(.query(PE_Q[11]), .ref(PE_R[11]), .H_lu(PE_H_S[11]), .H_l(PE_H_H[11]), .H_u(PE_H_V[11]), .I_u(PE_I_V[11]), .D_l(PE_D_H[11]), .H(H[11]), .I(I[11]), .D(D[11]), .clk(clk));
    PE PE13(.query(PE_Q[12]), .ref(PE_R[12]), .H_lu(PE_H_S[12]), .H_l(PE_H_H[12]), .H_u(PE_H_V[12]), .I_u(PE_I_V[12]), .D_l(PE_D_H[12]), .H(H[12]), .I(I[12]), .D(D[12]), .clk(clk));
    PE PE14(.query(PE_Q[13]), .ref(PE_R[13]), .H_lu(PE_H_S[13]), .H_l(PE_H_H[13]), .H_u(PE_H_V[13]), .I_u(PE_I_V[13]), .D_l(PE_D_H[13]), .H(H[13]), .I(I[13]), .D(D[13]), .clk(clk));
    PE PE15(.query(PE_Q[14]), .ref(PE_R[14]), .H_lu(PE_H_S[14]), .H_l(PE_H_H[14]), .H_u(PE_H_V[14]), .I_u(PE_I_V[14]), .D_l(PE_D_H[14]), .H(H[14]), .I(I[14]), .D(D[14]), .clk(clk));
    PE PE16(.query(PE_Q[15]), .ref(PE_R[15]), .H_lu(PE_H_S[15]), .H_l(PE_H_H[15]), .H_u(PE_H_V[15]), .I_u(PE_I_V[15]), .D_l(PE_D_H[15]), .H(H[15]), .I(I[15]), .D(D[15]), .clk(clk));

    always @(*) begin
        index_i_nxt[0] = index_i[0];
        index_j_nxt[0] = index_j[0];
        index_i_nxt[1] = index_i[1];
        index_j_nxt[1] = index_j[1];
        index_i_nxt[2] = index_i[2];
        index_j_nxt[2] = index_j[2];
        index_i_nxt[3] = index_i[3];
        index_j_nxt[3] = index_j[3];
        index_i_nxt[4] = index_i[4];
        index_j_nxt[4] = index_j[4];
        index_i_nxt[5] = index_i[5];
        index_j_nxt[5] = index_j[5];
        index_i_nxt[6] = index_i[6];
        index_j_nxt[6] = index_j[6];
        index_i_nxt[7] = index_i[7];
        index_j_nxt[7] = index_j[7];
        index_i_nxt[8] = index_i[8];
        index_j_nxt[8] = index_j[8];
        index_i_nxt[9] = index_i[9];
        index_j_nxt[9] = index_j[9];
        index_i_nxt[10] = index_i[10];
        index_j_nxt[10] = index_j[10];
        index_i_nxt[11] = index_i[11];
        index_j_nxt[11] = index_j[11];
        index_i_nxt[12] = index_i[12];
        index_j_nxt[12] = index_j[12];
        index_i_nxt[13] = index_i[13];
        index_j_nxt[13] = index_j[13];
        index_i_nxt[14] = index_i[14];
        index_j_nxt[14] = index_j[14];
        index_i_nxt[15] = index_i[15];
        index_j_nxt[15] = index_j[15];
        valid_w = valid;
        data_ref_w = data_ref;
        data_query_w = data_query;
        finish_w = finish_r;
        max_w = max_r;
        pos_ref_w = pos_ref_r;
        pos_query_w = pos_query_r;
        for ( i = 0; i < 16; i=i+1) begin
            PE_H_S[i] = 8'd0;
        end
        for ( i = 0; i < 16; i=i+1) begin
            PE_H_V[i] = 8'd0;
        end
        for ( i = 0; i < 16; i=i+1) begin
            PE_H_H[i] = 8'd0;
        end
        for ( i = 0; i < 16; i=i+1) begin
            PE_R[i] = 8'd0;
        end
        for ( i = 0; i < 16; i=i+1) begin
            PE_Q[i] = 8'd0;
        end
        for ( i = 0; i < 16; i=i+1) begin
            PE_D_H[i] = 8'd0;
        end
        for ( i = 0; i < 16; i=i+1) begin
            PE_I_V[i] = 8'd0;
        end

        case (state)
            CAL: begin
                
                // case for PE1
                    if (index_i[0] == 1 && index_j[0] == 1) begin
                        PE_R[0] = R[1];
                        PE_Q[0] = Q[1];
                        PE_H_S[0] = 8'b0;
                        PE_H_V[0] = 8'b0;
                        PE_H_H[0] = 8'b0;
                        PE_I_V[0] = -8'd32;
                        PE_D_H[0] = -8'd32;
                    end
                    else if (index_i[0] > 1 && index_j[0] == 1) begin
                        PE_R[0] = R[index_i[0]];
                        PE_Q[0] = Q[index_j[0]];
                        PE_H_S[0] = 8'b0;
                        PE_H_V[0] = 8'b0;
                        PE_H_H[0] = H_out[0];
                        PE_I_V[0] = -8'd32;
                        PE_D_H[0] = D_out[0];
                    end
                    else if (index_i[0] == 1 && index_j[0] > 1) begin
                        PE_R[0] = R[index_i[0]];
                        PE_Q[0] = Q[index_j[0]];
                        PE_H_S[0] = 8'b0;
                        PE_H_V[0] = H_last[1];
                        PE_H_H[0] = 8'b0;
                        PE_I_V[0] = I_last[1];
                        PE_D_H[0] = -8'd32;
                        // $display("I_last[0] = %d, H_last[0] = %d, index_i[0] = %d, index_j[0] = %d", I_last[1], H_last[1], index_i[0], index_j[0]);
                    end
                    else begin
                        PE_R[0] = R[index_i[0]];
                        PE_Q[0] = Q[index_j[0]];
                        PE_H_S[0] = H_last[index_i[0] - 1];
                        PE_H_V[0] = H_last[index_i[0]];
                        PE_H_H[0] = H_out[0];
                        PE_I_V[0] = I_last[index_i[0]];
                        PE_D_H[0] = D_out[0];
                    end

                

                // case for PE2
                if (index_i[1] == 1 && index_j[1] == 2 && index_i[0] > 1) begin
                    PE_R[1] = R[index_i[1]];
                    PE_Q[1] = Q[index_j[1]];
                    PE_H_S[1] = 8'b0;
                    PE_H_V[1] = H_out[0];
                    PE_H_H[1] = 8'b0;
                    PE_I_V[1] = I_out[0];
                    PE_D_H[1] = -8'd32;
                    // $display("H_out[0] = %d", H_out[0]);
                end
                else if (index_i[1] > 1) begin 
                    PE_R[1] = R[index_i[1]];
                    PE_Q[1] = Q[index_j[1]];
                    PE_H_S[1] = H_out_previous[0];
                    PE_H_V[1] = H_out[0];
                    PE_H_H[1] = H_out[1];
                    PE_I_V[1] = I_out[0];
                    PE_D_H[1] = D_out[1];
                end
                else if (index_i[1] == 1 && index_j[1] > 2) begin 
                    PE_R[1] = R[index_i[1]];
                    PE_Q[1] = Q[index_j[1]];
                    PE_H_S[1] = 8'b0;
                    PE_H_V[1] = H_out[0];
                    PE_H_H[1] = 8'b0;
                    PE_I_V[1] = I_out[0];
                    PE_D_H[1] = -8'd32;
                end
                else begin
                    PE_R[1] = R[index_i[1]];
                    PE_Q[1] = Q[index_j[1]];
                    PE_H_S[1] = 8'b0;
                    PE_H_V[1] = 8'b0;
                    PE_H_H[1] = 8'b0;
                    PE_I_V[1] = 8'b0;
                    PE_D_H[1] = 8'b0;
                end
                // end of case PE2

                // case for PE3
                if (index_i[2] == 1 && index_j[2] == 3 && index_i[0] > 2) begin
                    PE_R[2] = R[index_i[2]];
                    PE_Q[2] = Q[index_j[2]];
                    PE_H_S[2] = 8'b0;
                    PE_H_V[2] = H_out[1];
                    PE_H_H[2] = 8'b0;
                    PE_I_V[2] = I_out[1];
                    PE_D_H[2] = -8'd32;
                end
                else if(index_i[2] > 1) begin
                    PE_R[2] = R[index_i[2]];
                    PE_Q[2] = Q[index_j[2]];
                    PE_H_S[2] = H_out_previous[1];
                    PE_H_V[2] = H_out[1];
                    PE_H_H[2] = H_out[2];
                    PE_I_V[2] = I_out[1];
                    PE_D_H[2] = D_out[2];
                end
                else if (index_i[2] == 1 && index_j[2] > 3) begin 
                    PE_R[2] = R[index_i[2]];
                    PE_Q[2] = Q[index_j[2]];
                    PE_H_S[2] = 8'b0;
                    PE_H_V[2] = H_out[1];
                    PE_H_H[2] = 8'b0;
                    PE_I_V[2] = I_out[1];
                    PE_D_H[2] = -8'd32;
                end
                else begin
                    PE_R[2] = R[index_i[2]];
                    PE_Q[2] = Q[index_j[2]];
                    PE_H_S[2] = 8'b0;
                    PE_H_V[2] = 8'b0;
                    PE_H_H[2] = 8'b0;
                    PE_I_V[2] = 8'b0;
                    PE_D_H[2] = 8'b0;
                end
                // end of case PE3

                // case for PE4
                if (index_i[3] == 1 && index_j[3] == 4 && index_i[0] > 3) begin
                    PE_R[3] = R[index_i[3]];
                    PE_Q[3] = Q[index_j[3]];
                    PE_H_S[3] = 8'b0;
                    PE_H_V[3] = H_out[2];
                    PE_H_H[3] = 8'b0;
                    PE_I_V[3] = I_out[2];
                    PE_D_H[3] = -8'd32;
                end
                else if(index_i[3] > 1) begin
                    PE_R[3] = R[index_i[3]];
                    PE_Q[3] = Q[index_j[3]];
                    PE_H_S[3] = H_out_previous[2];
                    PE_H_V[3] = H_out[2];
                    PE_H_H[3] = H_out[3];
                    PE_I_V[3] = I_out[2];
                    PE_D_H[3] = D_out[3];
                end
                else if (index_i[3] == 1 && index_j[3] > 4) begin 
                    PE_R[3] = R[index_i[3]];
                    PE_Q[3] = Q[index_j[3]];
                    PE_H_S[3] = 8'b0;
                    PE_H_V[3] = H_out[2];
                    PE_H_H[3] = 8'b0;
                    PE_I_V[3] = I_out[2];
                    PE_D_H[3] = -8'd32;
                end
                else begin
                    PE_R[3] = R[index_i[3]];
                    PE_Q[3] = Q[index_j[3]];
                    PE_H_S[3] = 8'b0;
                    PE_H_V[3] = 8'b0;
                    PE_H_H[3] = 8'b0;
                    PE_I_V[3] = 8'b0;
                    PE_D_H[3] = 8'b0;
                end
                // end of case PE4

                // case for PE5
                if (index_i[4] == 1 && index_j[4] == 5 && index_i[0] > 4) begin
                    PE_R[4] = R[index_i[4]];
                    PE_Q[4] = Q[index_j[4]];
                    PE_H_S[4] = 8'b0;
                    PE_H_V[4] = H_out[3];
                    PE_H_H[4] = 8'b0;
                    PE_I_V[4] = I_out[3];
                    PE_D_H[4] = -8'd32;
                end
                else if(index_i[4] > 1) begin
                    PE_R[4] = R[index_i[4]];
                    PE_Q[4] = Q[index_j[4]];
                    PE_H_S[4] = H_out_previous[3];
                    PE_H_V[4] = H_out[3];
                    PE_H_H[4] = H_out[4];
                    PE_I_V[4] = I_out[3];
                    PE_D_H[4] = D_out[4];
                end
                else if (index_i[4] == 1 && index_j[4] > 5) begin 
                    PE_R[4] = R[index_i[4]];
                    PE_Q[4] = Q[index_j[4]];
                    PE_H_S[4] = 8'b0;
                    PE_H_V[4] = H_out[3];
                    PE_H_H[4] = 8'b0;
                    PE_I_V[4] = I_out[3];
                    PE_D_H[4] = -8'd32;
                end
                else begin
                    PE_R[4] = R[index_i[4]];
                    PE_Q[4] = Q[index_j[4]];
                    PE_H_S[4] = 8'b0;
                    PE_H_V[4] = 8'b0;
                    PE_H_H[4] = 8'b0;
                    PE_I_V[4] = 8'b0;
                    PE_D_H[4] = 8'b0;
                end
                // end of case PE5

                // case for PE6
                if (index_i[5] == 1 && index_j[5] == 6 && index_i[0] > 5) begin
                    PE_R[5] = R[index_i[5]];
                    PE_Q[5] = Q[index_j[5]];
                    PE_H_S[5] = 8'b0;
                    PE_H_V[5] = H_out[4];
                    PE_H_H[5] = 8'b0;
                    PE_I_V[5] = I_out[4];
                    PE_D_H[5] = -8'd32;
                end
                else if(index_i[5] > 1) begin
                    PE_R[5] = R[index_i[5]];
                    PE_Q[5] = Q[index_j[5]];
                    PE_H_S[5] = H_out_previous[4];
                    PE_H_V[5] = H_out[4];
                    PE_H_H[5] = H_out[5];
                    PE_I_V[5] = I_out[4];
                    PE_D_H[5] = D_out[5];
                end
                else if (index_i[5] == 1 && index_j[5] > 6) begin 
                    PE_R[5] = R[index_i[5]];
                    PE_Q[5] = Q[index_j[5]];
                    PE_H_S[5] = 8'b0;
                    PE_H_V[5] = H_out[4];
                    PE_H_H[5] = 8'b0;
                    PE_I_V[5] = I_out[4];
                    PE_D_H[5] = -8'd32;
                end
                else begin
                    PE_R[5] = R[index_i[5]];
                    PE_Q[5] = Q[index_j[5]];
                    PE_H_S[5] = 8'b0;
                    PE_H_V[5] = 8'b0;
                    PE_H_H[5] = 8'b0;
                    PE_I_V[5] = 8'b0;
                    PE_D_H[5] = 8'b0;
                end
                // end of case PE6

                // case for PE7
                if (index_i[6] == 1 && index_j[6] == 7 && index_i[0] > 6) begin
                    PE_R[6] = R[index_i[6]];
                    PE_Q[6] = Q[index_j[6]];
                    PE_H_S[6] = 8'b0;
                    PE_H_V[6] = H_out[5];
                    PE_H_H[6] = 8'b0;
                    PE_I_V[6] = I_out[5];
                    PE_D_H[6] = -8'd32;
                end
                else if(index_i[6] > 1) begin
                    PE_R[6] = R[index_i[6]];
                    PE_Q[6] = Q[index_j[6]];
                    PE_H_S[6] = H_out_previous[5];
                    PE_H_V[6] = H_out[5];
                    PE_H_H[6] = H_out[6];
                    PE_I_V[6] = I_out[5];
                    PE_D_H[6] = D_out[6];
                end
                else if (index_i[6] == 1 && index_j[6] > 7) begin 
                    PE_R[6] = R[index_i[6]];
                    PE_Q[6] = Q[index_j[6]];
                    PE_H_S[6] = 8'b0;
                    PE_H_V[6] = H_out[5];
                    PE_H_H[6] = 8'b0;
                    PE_I_V[6] = I_out[5];
                    PE_D_H[6] = -8'd32;
                end
                else begin
                    PE_R[6] = R[index_i[6]];
                    PE_Q[6] = Q[index_j[6]];
                    PE_H_S[6] = 8'b0;
                    PE_H_V[6] = 8'b0;
                    PE_H_H[6] = 8'b0;
                    PE_I_V[6] = 8'b0;
                    PE_D_H[6] = 8'b0;
                end
                // end of case PE7

                // case for PE8
                if (index_i[7] == 1 && index_j[7] == 8 && index_i[0] > 7) begin
                    PE_R[7] = R[index_i[7]];
                    PE_Q[7] = Q[index_j[7]];
                    PE_H_S[7] = 8'b0;
                    PE_H_V[7] = H_out[6];
                    PE_H_H[7] = 8'b0;
                    PE_I_V[7] = I_out[6];
                    PE_D_H[7] = -8'd32;
                end
                else if(index_i[7] > 1) begin
                    PE_R[7] = R[index_i[7]];
                    PE_Q[7] = Q[index_j[7]];
                    PE_H_S[7] = H_out_previous[6];
                    PE_H_V[7] = H_out[6];
                    PE_H_H[7] = H_out[7];
                    PE_I_V[7] = I_out[6];
                    PE_D_H[7] = D_out[7];
                end
                else if (index_i[7] == 1 && index_j[7] > 8) begin 
                    PE_R[7] = R[index_i[7]];
                    PE_Q[7] = Q[index_j[7]];
                    PE_H_S[7] = 8'b0;
                    PE_H_V[7] = H_out[6];
                    PE_H_H[7] = 8'b0;
                    PE_I_V[7] = I_out[6];
                    PE_D_H[7] = -8'd32;
                end
                else begin
                    PE_R[7] = R[index_i[7]];
                    PE_Q[7] = Q[index_j[7]];
                    PE_H_S[7] = 8'b0;
                    PE_H_V[7] = 8'b0;
                    PE_H_H[7] = 8'b0;
                    PE_I_V[7] = 8'b0;
                    PE_D_H[7] = 8'b0;
                end
                // end of case PE8

                // case for PE9
                if (index_i[8] == 1 && index_j[8] == 9 && index_i[0] > 8) begin
                    PE_R[8] = R[index_i[8]];
                    PE_Q[8] = Q[index_j[8]];
                    PE_H_S[8] = 8'b0;
                    PE_H_V[8] = H_out[7];
                    PE_H_H[8] = 8'b0;
                    PE_I_V[8] = I_out[7];
                    PE_D_H[8] = -8'd32;
                end
                else if(index_i[8] > 1) begin
                    PE_R[8] = R[index_i[8]];
                    PE_Q[8] = Q[index_j[8]];
                    PE_H_S[8] = H_out_previous[7];
                    PE_H_V[8] = H_out[7];
                    PE_H_H[8] = H_out[8];
                    PE_I_V[8] = I_out[7];
                    PE_D_H[8] = D_out[8];
                end
                else if (index_i[8] == 1 && index_j[8] > 9) begin 
                    PE_R[8] = R[index_i[8]];
                    PE_Q[8] = Q[index_j[8]];
                    PE_H_S[8] = 8'b0;
                    PE_H_V[8] = H_out[7];
                    PE_H_H[8] = 8'b0;
                    PE_I_V[8] = I_out[7];
                    PE_D_H[8] = -8'd32;
                end
                else begin
                    PE_R[8] = R[index_i[8]];
                    PE_Q[8] = Q[index_j[8]];
                    PE_H_S[8] = 8'b0;
                    PE_H_V[8] = 8'b0;
                    PE_H_H[8] = 8'b0;
                    PE_I_V[8] = 8'b0;
                    PE_D_H[8] = 8'b0;
                end
                // end of case PE9

                // case for PE10
                if (index_i[9] == 1 && index_j[9] == 10 && index_i[0] > 9) begin
                    PE_R[9] = R[index_i[9]];
                    PE_Q[9] = Q[index_j[9]];
                    PE_H_S[9] = 8'b0;
                    PE_H_V[9] = H_out[8];
                    PE_H_H[9] = 8'b0;
                    PE_I_V[9] = I_out[8];
                    PE_D_H[9] = -8'd32;
                end
                else if(index_i[9] > 1) begin
                    PE_R[9] = R[index_i[9]];
                    PE_Q[9] = Q[index_j[9]];
                    PE_H_S[9] = H_out_previous[8];
                    PE_H_V[9] = H_out[8];
                    PE_H_H[9] = H_out[9];
                    PE_I_V[9] = I_out[8];
                    PE_D_H[9] = D_out[9];
                end
                else if (index_i[9] == 1 && index_j[9] > 10) begin 
                    PE_R[9] = R[index_i[9]];
                    PE_Q[9] = Q[index_j[9]];
                    PE_H_S[9] = 8'b0;
                    PE_H_V[9] = H_out[8];
                    PE_H_H[9] = 8'b0;
                    PE_I_V[9] = I_out[8];
                    PE_D_H[9] = -8'd32;
                end
                else begin
                    PE_R[9] = R[index_i[9]];
                    PE_Q[9] = Q[index_j[9]];
                    PE_H_S[9] = 8'b0;
                    PE_H_V[9] = 8'b0;
                    PE_H_H[9] = 8'b0;
                    PE_I_V[9] = 8'b0;
                    PE_D_H[9] = 8'b0;
                end
                // end of case PE10

                // case for PE11
                if (index_i[10] == 1 && index_j[10] == 11 && index_i[0] > 10) begin
                    PE_R[10] = R[index_i[10]];
                    PE_Q[10] = Q[index_j[10]];
                    PE_H_S[10] = 8'b0;
                    PE_H_V[10] = H_out[9];
                    PE_H_H[10] = 8'b0;
                    PE_I_V[10] = I_out[9];
                    PE_D_H[10] = -8'd32;
                end
                else if(index_i[10] > 1) begin
                    PE_R[10] = R[index_i[10]];
                    PE_Q[10] = Q[index_j[10]];
                    PE_H_S[10] = H_out_previous[9];
                    PE_H_V[10] = H_out[9];
                    PE_H_H[10] = H_out[10];
                    PE_I_V[10] = I_out[9];
                    PE_D_H[10] = D_out[10];
                end
                else if (index_i[10] == 1 && index_j[10] > 11) begin 
                    PE_R[10] = R[index_i[10]];
                    PE_Q[10] = Q[index_j[10]];
                    PE_H_S[10] = 8'b0;
                    PE_H_V[10] = H_out[9];
                    PE_H_H[10] = 8'b0;
                    PE_I_V[10] = I_out[9];
                    PE_D_H[10] = -8'd32;
                end
                else begin
                    PE_R[10] = R[index_i[10]];
                    PE_Q[10] = Q[index_j[10]];
                    PE_H_S[10] = 8'b0;
                    PE_H_V[10] = 8'b0;
                    PE_H_H[10] = 8'b0;
                    PE_I_V[10] = 8'b0;
                    PE_D_H[10] = 8'b0;
                end
                // end of case PE11

                // case for PE12
                if (index_i[11] == 1 && index_j[11] == 12 && index_i[0] > 11) begin
                    PE_R[11] = R[index_i[11]];
                    PE_Q[11] = Q[index_j[11]];
                    PE_H_S[11] = 8'b0;
                    PE_H_V[11] = H_out[10];
                    PE_H_H[11] = 8'b0;
                    PE_I_V[11] = I_out[10];
                    PE_D_H[11] = -8'd32;
                end
                else if(index_i[11] > 1) begin
                    PE_R[11] = R[index_i[11]];
                    PE_Q[11] = Q[index_j[11]];
                    PE_H_S[11] = H_out_previous[10];
                    PE_H_V[11] = H_out[10];
                    PE_H_H[11] = H_out[11];
                    PE_I_V[11] = I_out[10];
                    PE_D_H[11] = D_out[11];
                end
                else if (index_i[11] == 1 && index_j[11] > 12) begin 
                    PE_R[11] = R[index_i[11]];
                    PE_Q[11] = Q[index_j[11]];
                    PE_H_S[11] = 8'b0;
                    PE_H_V[11] = H_out[10];
                    PE_H_H[11] = 8'b0;
                    PE_I_V[11] = I_out[10];
                    PE_D_H[11] = -8'd32;
                end
                else begin
                    PE_R[11] = R[index_i[11]];
                    PE_Q[11] = Q[index_j[11]];
                    PE_H_S[11] = 8'b0;
                    PE_H_V[11] = 8'b0;
                    PE_H_H[11] = 8'b0;
                    PE_I_V[11] = 8'b0;
                    PE_D_H[11] = 8'b0;
                end
                // end of case PE12

                // case for PE13
                if (index_i[12] == 1 && index_j[12] == 13 && index_i[0] > 12) begin
                    PE_R[12] = R[index_i[12]];
                    PE_Q[12] = Q[index_j[12]];
                    PE_H_S[12] = 8'b0;
                    PE_H_V[12] = H_out[11];
                    PE_H_H[12] = 8'b0;
                    PE_I_V[12] = I_out[11];
                    PE_D_H[12] = -8'd32;
                end
                else if(index_i[12] > 1) begin
                    PE_R[12] = R[index_i[12]];
                    PE_Q[12] = Q[index_j[12]];
                    PE_H_S[12] = H_out_previous[11];
                    PE_H_V[12] = H_out[11];
                    PE_H_H[12] = H_out[12];
                    PE_I_V[12] = I_out[11];
                    PE_D_H[12] = D_out[12];
                end
                else if (index_i[12] == 1 && index_j[12] > 13) begin 
                    PE_R[12] = R[index_i[12]];
                    PE_Q[12] = Q[index_j[12]];
                    PE_H_S[12] = 8'b0;
                    PE_H_V[12] = H_out[11];
                    PE_H_H[12] = 8'b0;
                    PE_I_V[12] = I_out[11];
                    PE_D_H[12] = -8'd32;
                end
                else begin
                    PE_R[12] = R[index_i[12]];
                    PE_Q[12] = Q[index_j[12]];
                    PE_H_S[12] = 8'b0;
                    PE_H_V[12] = 8'b0;
                    PE_H_H[12] = 8'b0;
                    PE_I_V[12] = 8'b0;
                    PE_D_H[12] = 8'b0;
                end
                // end of case PE13

                // case for PE14
                if (index_i[13] == 1 && index_j[13] == 14 && index_i[0] > 13) begin
                    PE_R[13] = R[index_i[13]];
                    PE_Q[13] = Q[index_j[13]];
                    PE_H_S[13] = 8'b0;
                    PE_H_V[13] = H_out[12];
                    PE_H_H[13] = 8'b0;
                    PE_I_V[13] = I_out[12];
                    PE_D_H[13] = -8'd32;
                end
                else if(index_i[13] > 1) begin
                    PE_R[13] = R[index_i[13]];
                    PE_Q[13] = Q[index_j[13]];
                    PE_H_S[13] = H_out_previous[12];
                    PE_H_V[13] = H_out[12];
                    PE_H_H[13] = H_out[13];
                    PE_I_V[13] = I_out[12];
                    PE_D_H[13] = D_out[13];
                end
                else if (index_i[13] == 1 && index_j[13] > 14) begin 
                    PE_R[13] = R[index_i[13]];
                    PE_Q[13] = Q[index_j[13]];
                    PE_H_S[13] = 8'b0;
                    PE_H_V[13] = H_out[12];
                    PE_H_H[13] = 8'b0;
                    PE_I_V[13] = I_out[12];
                    PE_D_H[13] = -8'd32;
                end
                else begin
                    PE_R[13] = R[index_i[13]];
                    PE_Q[13] = Q[index_j[13]];
                    PE_H_S[13] = 8'b0;
                    PE_H_V[13] = 8'b0;
                    PE_H_H[13] = 8'b0;
                    PE_I_V[13] = 8'b0;
                    PE_D_H[13] = 8'b0;
                end
                // end of case PE14

                // case for PE15
                if (index_i[14] == 1 && index_j[14] == 15 && index_i[0] > 14) begin
                    PE_R[14] = R[index_i[14]];
                    PE_Q[14] = Q[index_j[14]];
                    PE_H_S[14] = 8'b0;
                    PE_H_V[14] = H_out[13];
                    PE_H_H[14] = 8'b0;
                    PE_I_V[14] = I_out[13];
                    PE_D_H[14] = -8'd32;
                end
                else if(index_i[14] > 1) begin
                    PE_R[14] = R[index_i[14]];
                    PE_Q[14] = Q[index_j[14]];
                    PE_H_S[14] = H_out_previous[13];
                    PE_H_V[14] = H_out[13];
                    PE_H_H[14] = H_out[14];
                    PE_I_V[14] = I_out[13];
                    PE_D_H[14] = D_out[14];
                end
                else if (index_i[14] == 1 && index_j[14] > 15) begin 
                    PE_R[14] = R[index_i[14]];
                    PE_Q[14] = Q[index_j[14]];
                    PE_H_S[14] = 8'b0;
                    PE_H_V[14] = H_out[13];
                    PE_H_H[14] = 8'b0;
                    PE_I_V[14] = I_out[13];
                    PE_D_H[14] = -8'd32;
                end
                else begin
                    PE_R[14] = R[index_i[14]];
                    PE_Q[14] = Q[index_j[14]];
                    PE_H_S[14] = 8'b0;
                    PE_H_V[14] = 8'b0;
                    PE_H_H[14] = 8'b0;
                    PE_I_V[14] = 8'b0;
                    PE_D_H[14] = 8'b0;
                end
                // end of case PE15


                // case for PE16
                if (index_i[15] == 1 && index_j[15] == 16 && index_i[0] > 15) begin
                    PE_R[15] = R[index_i[15]];
                    PE_Q[15] = Q[index_j[15]];
                    PE_H_S[15] = 8'b0;
                    PE_H_V[15] = H_out[14];
                    PE_H_H[15] = 8'b0;
                    PE_I_V[15] = I_out[14];
                    PE_D_H[15] = -8'd32;
                end
                else if(index_i[15] > 1) begin
                    PE_R[15] = R[index_i[15]];
                    PE_Q[15] = Q[index_j[15]];
                    PE_H_S[15] = H_out_previous[14];
                    PE_H_V[15] = H_out[14];
                    PE_H_H[15] = H_out[15];
                    PE_I_V[15] = I_out[14];
                    PE_D_H[15] = D_out[15];
                end
                else if (index_i[15] == 1 && index_j[15] > 16) begin 
                    PE_R[15] = R[index_i[15]];
                    PE_Q[15] = Q[index_j[15]];
                    PE_H_S[15] = 8'b0;
                    PE_H_V[15] = H_out[14];
                    PE_H_H[15] = 8'b0;
                    PE_I_V[15] = I_out[14];
                    PE_D_H[15] = -8'd32;
                end
                else begin
                    PE_R[15] = R[index_i[15]];
                    PE_Q[15] = Q[index_j[15]];
                    PE_H_S[15] = 8'b0;
                    PE_H_V[15] = 8'b0;
                    PE_H_H[15] = 8'b0;
                    PE_I_V[15] = 8'b0;
                    PE_D_H[15] = -8'd32;
                end


                // calculate the max
                if (H[0] > max_r) begin
                    max_w = H[0];
                    pos_ref_w = index_i[0];
                    pos_query_w = index_j[0];
                end
                else if (H[1] > max_r) begin
                    max_w = H[1];
                    pos_ref_w = index_i[1];
                    pos_query_w = index_j[1];
                end
                else if (H[2] > max_r) begin
                    max_w = H[2];
                    pos_ref_w = index_i[2];
                    pos_query_w = index_j[2];
                end
                else if (H[3] > max_r) begin
                    max_w = H[3];
                    pos_ref_w = index_i[3];
                    pos_query_w = index_j[3];
                end
                else if (H[4] > max_r) begin
                    max_w = H[4];
                    pos_ref_w = index_i[4];
                    pos_query_w = index_j[4];
                end
                else if (H[5] > max_r) begin
                    max_w = H[5];
                    pos_ref_w = index_i[5];
                    pos_query_w = index_j[5];
                end
                else if (H[6] > max_r) begin
                    max_w = H[6];
                    pos_ref_w = index_i[6];
                    pos_query_w = index_j[6];
                end
                else if (H[7] > max_r) begin
                    max_w = H[7];
                    pos_ref_w = index_i[7];
                    pos_query_w = index_j[7];
                end
                else if (H[8] > max_r) begin
                    max_w = H[8];
                    pos_ref_w = index_i[8];
                    pos_query_w = index_j[8];
                end
                else if (H[9] > max_r) begin
                    max_w = H[9];
                    pos_ref_w = index_i[9];
                    pos_query_w = index_j[9];
                end
                else if (H[10] > max_r) begin
                    max_w = H[10];
                    pos_ref_w = index_i[10];
                    pos_query_w = index_j[10];
                end
                else if (H[11] > max_r) begin
                    max_w = H[11];
                    pos_ref_w = index_i[11];
                    pos_query_w = index_j[11];
                end
                else if (H[12] > max_r) begin
                    max_w = H[12];
                    pos_ref_w = index_i[12];
                    pos_query_w = index_j[12];
                end
                else if (H[13] > max_r) begin
                    max_w = H[13];
                    pos_ref_w = index_i[13];
                    pos_query_w = index_j[13];
                end
                else if (H[14] > max_r) begin
                    max_w = H[14];
                    pos_ref_w = index_i[14];
                    pos_query_w = index_j[14];
                end
                else if (H[15] > max_r) begin
                    max_w = H[15];
                    pos_ref_w = index_i[15];
                    pos_query_w = index_j[15];
                end
                else begin
                    max_w = max_r;
                    pos_ref_w = pos_ref_r;
                    pos_query_w = pos_query_r;
                end

                // index for PE1
                if (index_i[0] < 7'd64) begin
                    index_i_nxt[0] = index_i[0] + 7'b1;
                    index_j_nxt[0] = index_j[0];
                    if(index_j[0] == 1) begin
                    end
                end
                else if(index_i[0] == 7'd64 && index_j[0] < 7'd33) begin
                    index_i_nxt[0] = 7'b1;
                    index_j_nxt[0] = index_j[0] + 7'd16;
                end
                else begin
                    index_i_nxt[0] = index_i[0];
                    index_j_nxt[0] = index_j[0];
                end

                // index for PE2
                if (index_i[1] < 7'd64 && ((index_i[0] > 1) || (index_j[0] > 1))) begin
                    index_i_nxt[1] = index_i[1] + 7'b1;
                    index_j_nxt[1] = index_j[1];
                end
                else if(index_i[1] == 7'd64 && index_j[1] < 7'd34) begin
                    index_i_nxt[1] = 7'b1;
                    index_j_nxt[1] = index_j[1] + 7'd16;
                end
                else begin
                    index_i_nxt[1] = index_i[1];
                    index_j_nxt[1] = index_j[1];
                end

                // index for PE3
                if (index_i[2] < 7'd64 && ((index_i[0] > 2) || (index_j[0] > 1))) begin
                    index_i_nxt[2] = index_i[2] + 7'b1;
                    index_j_nxt[2] = index_j[2];
                end
                else if(index_i[2] == 7'd64 && index_j[2] < 7'd35) begin
                    index_i_nxt[2] = 7'b1;
                    index_j_nxt[2] = index_j[2] + 7'd16;
                end
                else begin
                    index_i_nxt[2] = index_i[2];
                    index_j_nxt[2] = index_j[2];
                end

                // index for PE4
                if (index_i[3] < 7'd64 && ((index_i[0] > 3) || (index_j[0] > 1))) begin
                    index_i_nxt[3] = index_i[3] + 7'b1;
                    index_j_nxt[3] = index_j[3];
                end
                else if(index_i[3] == 7'd64 && index_j[3] < 7'd36) begin
                    index_i_nxt[3] = 7'b1;
                    index_j_nxt[3] = index_j[3] + 7'd16;
                end
                else begin
                    index_i_nxt[3] = index_i[3];
                    index_j_nxt[3] = index_j[3];
                end

                // index for PE5
                if (index_i[4] < 7'd64 && ((index_i[0] > 4) || (index_j[0] > 1))) begin
                    index_i_nxt[4] = index_i[4] + 7'b1;
                    index_j_nxt[4] = index_j[4];
                end
                else if(index_i[4] == 7'd64 && index_j[4] < 7'd37) begin
                    index_i_nxt[4] = 7'b1;
                    index_j_nxt[4] = index_j[4] + 7'd16;
                end
                else begin
                    index_i_nxt[4] = index_i[4];
                    index_j_nxt[4] = index_j[4];
                end

                // index for PE6
                if (index_i[5] < 7'd64 && ((index_i[0] > 5) || (index_j[0] > 1))) begin
                    index_i_nxt[5] = index_i[5] + 7'b1;
                    index_j_nxt[5] = index_j[5];
                end
                else if(index_i[5] == 7'd64 && index_j[5] < 7'd38) begin
                    index_i_nxt[5] = 7'b1;
                    index_j_nxt[5] = index_j[5] + 7'd16;
                end
                else begin
                    index_i_nxt[5] = index_i[5];
                    index_j_nxt[5] = index_j[5];
                end

                // index for PE7
                if (index_i[6] < 7'd64 && ((index_i[0] > 6) || (index_j[0] > 1))) begin
                    index_i_nxt[6] = index_i[6] + 7'b1;
                    index_j_nxt[6] = index_j[6];
                end
                else if(index_i[6] == 7'd64 && index_j[6] < 7'd39) begin
                    index_i_nxt[6] = 7'b1;
                    index_j_nxt[6] = index_j[6] + 7'd16;
                end
                else begin
                    index_i_nxt[6] = index_i[6];
                    index_j_nxt[6] = index_j[6];
                end

                // index for PE8
                if (index_i[7] < 7'd64 && ((index_i[0] > 7) || (index_j[0] > 1))) begin
                    index_i_nxt[7] = index_i[7] + 7'b1;
                    index_j_nxt[7] = index_j[7];
                end
                else if(index_i[7] == 7'd64 && index_j[7] < 7'd40) begin
                    index_i_nxt[7] = 7'b1;
                    index_j_nxt[7] = index_j[7] + 7'd16;
                end
                else begin
                    index_i_nxt[7] = index_i[7];
                    index_j_nxt[7] = index_j[7];
                end

                // index for PE9
                if (index_i[8] < 7'd64 && ((index_i[0] > 8) || (index_j[0] > 1))) begin
                    index_i_nxt[8] = index_i[8] + 7'b1;
                    index_j_nxt[8] = index_j[8];
                end
                else if(index_i[8] == 7'd64 && index_j[8] < 7'd41) begin
                    index_i_nxt[8] = 7'b1;
                    index_j_nxt[8] = index_j[8] + 7'd16;
                end
                else begin
                    index_i_nxt[8] = index_i[8];
                    index_j_nxt[8] = index_j[8];
                end

                // index for PE10
                if (index_i[9] < 7'd64 && ((index_i[0] > 9) || (index_j[0] > 1))) begin
                    index_i_nxt[9] = index_i[9] + 7'b1;
                    index_j_nxt[9] = index_j[9];
                end
                else if(index_i[9] == 7'd64 && index_j[9] < 7'd42) begin
                    index_i_nxt[9] = 7'b1;
                    index_j_nxt[9] = index_j[9] + 7'd16;
                end
                else begin
                    index_i_nxt[9] = index_i[9];
                    index_j_nxt[9] = index_j[9];
                end

                // index for PE11
                if (index_i[10] < 7'd64 && ((index_i[0] > 10) || (index_j[0] > 1))) begin
                    index_i_nxt[10] = index_i[10] + 7'b1;
                    index_j_nxt[10] = index_j[10];
                end
                else if(index_i[10] == 7'd64 && index_j[10] < 7'd43) begin
                    index_i_nxt[10] = 7'b1;
                    index_j_nxt[10] = index_j[10] + 7'd16;
                end
                else begin
                    index_i_nxt[10] = index_i[10];
                    index_j_nxt[10] = index_j[10];
                end

                // index for PE12
                if (index_i[11] < 7'd64 && ((index_i[0] > 11) || (index_j[0] > 1))) begin
                    index_i_nxt[11] = index_i[11] + 7'b1;
                    index_j_nxt[11] = index_j[11];
                end
                else if(index_i[11] == 7'd64 && index_j[11] < 7'd44) begin
                    index_i_nxt[11] = 7'b1;
                    index_j_nxt[11] = index_j[11] + 7'd16;
                end
                else begin
                    index_i_nxt[11] = index_i[11];
                    index_j_nxt[11] = index_j[11];
                end

                // index for PE13
                if (index_i[12] < 7'd64 && ((index_i[0] > 12) || (index_j[0] > 1))) begin
                    index_i_nxt[12] = index_i[12] + 7'b1;
                    index_j_nxt[12] = index_j[12];
                end
                else if(index_i[12] == 7'd64 && index_j[12] < 7'd45) begin
                    index_i_nxt[12] = 7'b1;
                    index_j_nxt[12] = index_j[12] + 7'd16;
                end
                else begin
                    index_i_nxt[12] = index_i[12];
                    index_j_nxt[12] = index_j[12];
                end

                // index for PE14
                if (index_i[13] < 7'd64 && ((index_i[0] > 13) || (index_j[0] > 1))) begin
                    index_i_nxt[13] = index_i[13] + 7'b1;
                    index_j_nxt[13] = index_j[13];
                end
                else if(index_i[13] == 7'd64 && index_j[13] < 7'd46) begin
                    index_i_nxt[13] = 7'b1;
                    index_j_nxt[13] = index_j[13] + 7'd16;
                end
                else begin
                    index_i_nxt[13] = index_i[13];
                    index_j_nxt[13] = index_j[13];
                end

                // index for PE15
                if (index_i[14] < 7'd64 && ((index_i[0] > 14) || (index_j[0] > 1))) begin
                    index_i_nxt[14] = index_i[14] + 7'b1;
                    index_j_nxt[14] = index_j[14];
                end
                else if(index_i[14] == 7'd64 && index_j[14] < 7'd47) begin
                    index_i_nxt[14] = 1;
                    index_j_nxt[14] = index_j[14] + 7'd16;
                end
                else begin
                    index_i_nxt[14] = index_i[14];
                    index_j_nxt[14] = index_j[14];
                end

                // index for PE16
                if (index_i[15] < 7'd64 && ((index_i[0] > 15) || (index_j[0] > 1))) begin
                    index_i_nxt[15] = index_i[15] + 7'b1;
                    index_j_nxt[15] = index_j[15];
                end
                else if(index_i[15] == 7'd64 && index_j[15] < 7'd48) begin
                    index_i_nxt[15] = 1;
                    index_j_nxt[15] = index_j[15] + 7'd16;
                end
                else if(index_i[15] == 7'd64 && index_j[15] == 7'd48) begin
                    finish_w = 1'b1;
                end
                else begin
                    index_i_nxt[15] = index_i[15];
                    index_j_nxt[15] = index_j[15];
                end
            end
            default: begin
                
            end
        endcase
        // case (state)
        //     READY: finish_w = 1;
        //     default: finish_w = finish_r;
        // endcase
    end

//------------------------------------------------------------------
// sequential part
//------------------------------------------------------------------
    always@(posedge clk or posedge reset) begin
        if(reset) begin
            R_nxt_r <= 0;
            Q_nxt_r <= 0;
            index_i[0] <= 1;
            index_j[0] <= 1;
            index_i[1] <= 1;
            index_j[1] <= 2;
            index_i[2] <= 1;
            index_j[2] <= 3;
            index_i[3] <= 1;
            index_j[3] <= 4;
            index_i[4] <= 1;
            index_j[4] <= 5;
            index_i[5] <= 1;
            index_j[5] <= 6;
            index_i[6] <= 1;
            index_j[6] <= 7;
            index_i[7] <= 1;
            index_j[7] <= 8;
            index_i[8] <= 1;
            index_j[8] <= 9;
            index_i[9] <= 1;
            index_j[9] <= 10;
            index_i[10] <= 1;
            index_j[10] <= 11;
            index_i[11] <= 1;
            index_j[11] <= 12;
            index_i[12] <= 1;
            index_j[12] <= 13;
            index_i[13] <= 1;
            index_j[13] <= 14;
            index_i[14] <= 1;
            index_j[14] <= 15;
            index_i[15] <= 1;
            index_j[15] <= 16;
            counter_R <= 1;
            counter_Q <= 1;
            counter_cal <= 0;
            state <= 0;
            finish_r <= 0;
            max_r <= 0;
            pos_ref_r <= 0;
            pos_query_r <= 0;
            valid_r <= 0;
            data_ref_r <= 0;
            data_query_r <= 0;

            // $display("Q: %d, R: %d\n", counter_Q, counter_R);

        end
        else begin
            index_i[0] <= index_i_nxt[0];
            index_j[0] <= index_j_nxt[0];
            index_i[1] <= index_i_nxt[1];
            index_j[1] <= index_j_nxt[1];
            index_i[2] <= index_i_nxt[2];
            index_j[2] <= index_j_nxt[2];
            index_i[3] <= index_i_nxt[3];
            index_j[3] <= index_j_nxt[3];
            index_i[4] <= index_i_nxt[4];
            index_j[4] <= index_j_nxt[4];
            index_i[5] <= index_i_nxt[5];
            index_j[5] <= index_j_nxt[5];
            index_i[6] <= index_i_nxt[6];
            index_j[6] <= index_j_nxt[6];
            index_i[7] <= index_i_nxt[7];
            index_j[7] <= index_j_nxt[7];
            index_i[8] <= index_i_nxt[8];
            index_j[8] <= index_j_nxt[8];
            index_i[9] <= index_i_nxt[9];
            index_j[9] <= index_j_nxt[9];
            index_i[10] <= index_i_nxt[10];
            index_j[10] <= index_j_nxt[10];
            index_i[11] <= index_i_nxt[11];
            index_j[11] <= index_j_nxt[11];
            index_i[12] <= index_i_nxt[12];
            index_j[12] <= index_j_nxt[12];
            index_i[13] <= index_i_nxt[13];
            index_j[13] <= index_j_nxt[13];
            index_i[14] <= index_i_nxt[14];
            index_j[14] <= index_j_nxt[14];
            index_i[15] <= index_i_nxt[15];
            index_j[15] <= index_j_nxt[15];
            state <= state_nxt;
            counter_R <= counter_R_nxt;
            counter_Q <= counter_Q_nxt;
            counter_cal <= counter_cal_nxt;
            R[counter_R] <= R_nxt_w;
            Q[counter_Q] <= Q_nxt_w;
            finish_r <= finish_w;
            max_r <= max_w;
            pos_ref_r <= pos_ref_w;
            pos_query_r <= pos_query_w;
            R_nxt_r <= R_nxt_w;
            Q_nxt_r <= Q_nxt_w;
            valid_r <= valid_w;
            data_query_r <= data_query_w;
            data_ref_r <= data_ref_w;
            for ( i = 0; i < 16; i=i+1) begin
                H_out[i] <= H[i];
                H_out_previous[i] <= H_out[i];
                I_out[i] <= I[i];
                D_out[i] <= D[i];
            end
            H_last[index_i[15]] <= H[15];
            I_last[index_i[15]] <= I[15];
            
        end
    end
    
endmodule

module PE (query, ref, H_lu, H_l, H_u, I_u, D_l, H, I, D, clk);
    input  [1:0]  query;
    input  [1:0]  ref;
    input         clk;
    input  signed [7:0]  H_l, H_u, H_lu, I_u, D_l;
    output reg signed [7:0]  H, I, D;
    reg signed [3:0] S;
    
    
    always @(*) begin
        I = (((H_u - 6'sd2) > (I_u - 6'sd1)) ? (H_u - 6'sd2) : (I_u - 6'sd1));
        D = (((H_l - 6'sd2) > (D_l - 6'sd1)) ? (H_l - 6'sd2) : (D_l - 6'sd1));
        S = ((ref == query) ? 2 : -1);
        if (H_lu + S >= I && H_lu + S >= D && H_lu + S >= 0) begin
            H = H_lu + S;
        end
        else if (I >= H_lu + S && I >= D && I >= 0) begin
            H = I;
        end
        else if (D >= H_lu + S && D >=I && D >= 0) begin
            H = D;
        end
        else begin
            H = 8'd0;
        end
    end

endmodule